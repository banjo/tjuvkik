import Foundation
import Testing
@testable import TjuvkikCore

struct ConfigLoaderTests {
    @Test func defaultFilesLoadWithoutWarnings() throws {
        let fixture = ConfigFixture([:])
        try DefaultConfig.write(to: fixture.directory)
        let loaded = try fixture.load().get()
        #expect(loaded.warnings.isEmpty)
        #expect(loaded.config.theme == .darkGlass)
        #expect(loaded.config.tiles.map(\.panel) == ["disk"])
        #expect(loaded.config.tiles[0].kind == .cli)
        #expect(loaded.config.tiles[0].command == "df -h /")
        #expect(loaded.config.tiles[0].mode == .interval)
        #expect(loaded.config.tiles[0].size == .m)
        #expect(loaded.config.tiles[0].every == 300)
        #expect(loaded.config.tiles[0].directory.lastPathComponent == "disk")
    }

    @Test func writingDefaultsKeepsExistingFiles() throws {
        let fixture = ConfigFixture(["config.json": #"{ "theme": "dracula" }"#])
        try DefaultConfig.write(to: fixture.directory)
        #expect(try fixture.load().get().config.theme == .dracula)
        #expect(FileManager.default.fileExists(atPath: fixture.directory.appending(path: "panels/disk/panel.jsonc").path))
    }

    @Test func defaultsDontDuplicateAJSONFile() throws {
        let fixture = ConfigFixture(["config.json": "{}"])
        try DefaultConfig.write(to: fixture.directory)
        #expect(!FileManager.default.fileExists(atPath: fixture.directory.appending(path: "config.jsonc").path))
    }

    @Test func jsoncAndJSONBothWork() throws {
        let config = try load([
            "config.jsonc": #"{ "theme": "mine", "panels": [{ "panel": "a" }, { "panel": "b" }] }"#,
            "panels/a/panel.jsonc": #"{ "type": "cli", "command": "ls" }"#,
            "panels/b/panel.json": #"{ "type": "cli", "command": "pwd" }"#,
            "themes/mine.json": #"{ "extends": "dracula" }"#,
        ]).config
        #expect(config.tiles.map(\.command) == ["ls", "pwd"])
        #expect(config.theme == .dracula)
    }

    @Test func jsoncWinsOverJSONWithAWarning() throws {
        let loaded = try load(["config.jsonc": #"{ "theme": "dracula" }"#, "config.json": #"{ "theme": "light-glass" }"#])
        #expect(loaded.config.theme == .dracula)
        #expect(loaded.warnings.map(\.description) == ["config.json: ignored, because config.jsonc exists"])
    }

    @Test func emptyConfigGetsDefaults() throws {
        let config = try load(["config.json": "{}"]).config
        #expect(config.trigger == .fn)
        #expect(config.launchAtLogin)
        #expect(config.tiles.isEmpty)
    }

    @Test func missingConfigIsAnError() {
        #expect(errors([:]) == ["config.jsonc: can't read the file"])
    }

    @Test func commentsAndTrailingCommas() throws {
        let config = try load(["config.json": """
        {
          // a comment
          "theme": "dracula", /* another */
          "panels": [{ "panel": "x", "size": "l", },],
        }
        """, "panels/x/panel.json": #"{ "type": "cli", "command": "ls", }"#]).config
        #expect(config.theme == .dracula)
        #expect(config.tiles[0].size == .l)
    }

    @Test func laterValuesFallBackWithAWarning() throws {
        let loaded = try load(["config.json": #"{ "view": "spotlight", "layout": "edges" }"#])
        #expect(loaded.config.view == .bento)
        #expect(loaded.config.layout == .framed)
        #expect(loaded.warnings.map(\.path) == ["view", "layout"])
    }

    @Test func syntaxErrorIsReported() {
        let issues = errors(["config.json": #"{ "theme": "dracula" "view": "bento" }"#])
        #expect(issues.count == 1)
        #expect(issues[0].hasPrefix("config.json: "))
    }

    @Test func wrongTypeHasAPath() {
        #expect(errors(["config.json": #"{ "panels": [{ "panel": "x", "size": 3 }] }"#])
            == ["config.json: panels[0].size: expected a string"])
    }

    @Test func panelSizeInConfigWinsOverThePanels() throws {
        let config = try load([
            "config.json": #"{ "panels": [{ "panel": "pods", "size": "l" }, { "panel": "pods" }] }"#,
            "panels/pods/panel.json": #"{ "type": "cli", "command": "kubectl get pods", "size": "m" }"#,
        ]).config
        #expect(config.tiles.map(\.size) == [.l, .m])
        #expect(config.tiles[0].title == "pods")
    }

    @Test func unknownPanel() {
        #expect(errors(["config.json": #"{ "panels": [{ "panel": "weather" }] }"#])
            == [#"config.json: panels[0].panel: no panel "weather": create panels/weather/panel.jsonc"#])
    }

    @Test func panelNamesStayInPanels() {
        #expect(errors(["config.json": #"{ "panels": [{ "panel": "../x" }] }"#])
            == [#"config.json: panels[0].panel: "../x" isn't a panel name"#])
    }

    @Test func everyProblemIsReportedWithItsFile() {
        let issues = errors([
            "config.json": #"{ "theme": "nope", "panels": [{ "panel": "pods", "size": "huge" }, { "panel": "gh" }] }"#,
            "panels/pods/panel.json": #"{ "type": "cli", "every": "soon" }"#,
            "panels/gh/panel.json": #"{ "type": "web", "command": "x" }"#,
        ])
        #expect(issues == [
            #"config.json: theme: unknown theme "nope", expected one of "dark-glass", "dracula", "light-glass""#,
            #"config.json: panels[0].size: unknown size "huge", expected "s", "m", "l" or "xl""#,
            "panels/pods/panel.json: command: a cli panel needs a command",
            #"panels/pods/panel.json: every: can't read "soon", write it like "30s", "5m" or "1h""#,
            #"panels/gh/panel.json: type: unknown type "web", expected one of "script", "cli", "chart", "meters", "grid", "timeline", "stats", "markdown", "keyvalue", "table", "feed", "checklist""#,
        ])
    }

    @Test func aContentTypeIsAScriptPanel() throws {
        let tile = try load([
            "config.json": #"{ "panels": [{ "panel": "x" }] }"#,
            "panels/x/panel.json": #"{ "type": "stats", "command": "./stats.sh" }"#,
        ]).config.tiles[0]
        #expect(tile.kind == .script)
        #expect(tile.content == .stats)
        #expect(tile.typeName == "stats")
    }

    @Test func intervalHasAMinimum() {
        #expect(errors([
            "config.json": #"{ "panels": [{ "panel": "x" }] }"#,
            "panels/x/panel.json": #"{ "type": "cli", "command": "ls", "every": "1s" }"#,
        ]) == [#"panels/x/panel.json: every: must be at least 5s, got "1s""#])
    }

    @Test func panelsThatDontFitAreWarnedAndLeftOut() throws {
        let loaded = try load([
            "config.json": #"{ "panels": [{ "panel": "x", "size": "xl" }, { "panel": "x", "size": "xl" }, { "panel": "x" }] }"#,
            "panels/x/panel.json": #"{ "type": "cli", "command": "ls" }"#,
        ])
        #expect(loaded.config.tiles.map(\.slot) == [
            GridSlot(column: 0, row: 0, columns: 2, rows: 3),
            GridSlot(column: 2, row: 0, columns: 2, rows: 3),
            nil,
        ])
        #expect(loaded.warnings.map(\.path) == ["panels[2]"])
    }

    @Test func streamModeAndMetadata() throws {
        let tile = try load([
            "config.json": #"{ "panels": [{ "panel": "agents" }] }"#,
            "panels/agents/panel.jsonc": #"""
            { "type": "script", "mode": "stream", "command": "agent-watcher list --json --watch",
              "description": "Coding agents", "author": "banjo", "version": "1.0.0", "requires": ["agent-watcher", "jq"] }
            """#,
        ]).config.tiles[0]
        #expect(tile.mode == .stream)
        #expect(tile.requires == ["agent-watcher", "jq"])
    }

    @Test func badModeAndRequires() {
        #expect(errors([
            "config.json": #"{ "panels": [{ "panel": "x" }] }"#,
            "panels/x/panel.json": #"{ "type": "cli", "command": "ls", "mode": "push", "requires": ["/bin/ls"] }"#,
        ]) == [
            #"panels/x/panel.json: mode: unknown mode "push", expected "interval" or "stream""#,
            #"panels/x/panel.json: requires[0]: "/bin/ls" isn't a command name"#,
        ])
    }

    @Test func menuBarPanel() throws {
        let panel = #"{ "type": "cli", "command": "ls" }"#
        let config = try load([
            "config.json": #"{ "menuBar": "x", "panels": [{ "panel": "x" }] }"#, "panels/x/panel.json": panel,
        ]).config
        #expect(config.menuBar == ["x"])
        #expect(errors(["config.json": #"{ "menuBar": "y", "panels": [{ "panel": "x" }] }"#, "panels/x/panel.json": panel])
            == [#"config.json: menuBar: "y" isn't in panels"#])
        #expect(errors(["config.json": #"{ "menuBar": ["x", "y"], "panels": [{ "panel": "x" }] }"#, "panels/x/panel.json": panel])
            == [#"config.json: menuBar[1]: "y" isn't in panels"#])
    }

    @Test func holdMsRange() {
        #expect(errors(["config.json": #"{ "trigger": { "holdMs": 10 } }"#])
            == ["config.json: trigger.holdMs: must be between 50 and 2000, got 10"])
    }

    private func trigger(_ json: String) throws -> Trigger {
        try load(["config.json": #"{ "trigger": "# + json + " }"]).config.trigger
    }

    @Test func triggerKeysHoldByDefault() throws {
        #expect(try trigger("{}") == .fn)
        #expect(try trigger(#"{ "holdMs": 400 }"#) == Trigger(input: .key(.fn), mode: .hold, holdMilliseconds: 400))
        #expect(try trigger(#"{ "key": "rightOption" }"#) == Trigger(input: .key(.rightOption), mode: .hold))
        #expect(try trigger(#"{ "key": "rightCommand", "mode": "toggle" }"#) == Trigger(input: .key(.rightCommand), mode: .toggle))
    }

    @Test func triggerShortcutsToggleByDefault() throws {
        let shortcut = try Shortcut.parse("⌃⌥Space").get()
        #expect(try trigger(#"{ "shortcut": "ctrl+option+space" }"#) == Trigger(input: .shortcut(shortcut), mode: .toggle))
        #expect(try trigger(#"{ "shortcut": "⌃⌥Space", "mode": "hold", "holdMs": 100 }"#)
            == Trigger(input: .shortcut(shortcut), mode: .hold, holdMilliseconds: 100))
    }

    @Test func holdMsWithToggleWarns() throws {
        let loaded = try load(["config.json": #"{ "trigger": { "shortcut": "F18", "holdMs": 100 } }"#])
        #expect(loaded.warnings.map(\.description) == [#"config.json: trigger.holdMs: only applies with "mode": "hold""#])
    }

    @Test func triggerErrors() {
        func error(_ json: String) -> [String] { errors(["config.json": #"{ "trigger": "# + json + " }"]) }
        #expect(error(#"{ "key": "fn", "shortcut": "F18" }"#) == [#"config.json: trigger: set "key" or "shortcut", not both"#])
        #expect(error(#"{ "key": "leftOption" }"#) == [
            #"config.json: trigger.key: unknown key "leftOption", expected one of "fn", "rightOption", "rightCommand", "rightControl", "rightShift""#,
        ])
        #expect(error(#"{ "key": "capsLock" }"#) == [
            #"config.json: trigger.key: caps lock can't be held, macOS locks it on press: map it to F18 and set "shortcut": "F18""#,
        ])
        #expect(error(#"{ "shortcut": "space" }"#) == [#"config.json: trigger.shortcut: needs ⌃, ⌥ or ⌘, so it doesn't take a key you type"#])
        #expect(error(#"{ "mode": "press" }"#) == [#"config.json: trigger.mode: unknown mode "press", expected "hold", "toggle" or "doubleTap""#])
        #expect(error(#"{ "shortcut": "F18", "mode": "doubleTap" }"#) == [#"config.json: trigger.mode: "doubleTap" only works with "key""#])
        #expect(error(#"{ "mode": "doubleTap", "doubleTapMs": 100 }"#) == ["config.json: trigger.doubleTapMs: must be between 150 and 600, got 100"])
    }

    @Test func triggerDoubleTap() throws {
        #expect(try trigger(#"{ "mode": "doubleTap" }"#) == Trigger(input: .key(.fn), mode: .doubleTap))
        #expect(try trigger(#"{ "key": "rightCommand", "mode": "doubleTap", "doubleTapMs": 400 }"#)
            == Trigger(input: .key(.rightCommand), mode: .doubleTap, doubleTapMilliseconds: 400))
    }

    @Test func triggerDoubleTapWarnings() throws {
        func warnings(_ json: String) throws -> [String] {
            try load(["config.json": #"{ "trigger": "# + json + " }"]).warnings.map(\.description)
        }
        #expect(try warnings(#"{ "doubleTapMs": 300 }"#) == [#"config.json: trigger.doubleTapMs: only applies with "mode": "doubleTap""#])
        #expect(try warnings(#"{ "mode": "doubleTap", "holdMs": 300 }"#) == [#"config.json: trigger.holdMs: only applies with "mode": "hold""#])
    }

    // MARK: Background

    /// A panel with `panel.json`'s extra keys, in a config that shows it.
    private func background(_ panel: String = "", _ ref: String = "") throws -> Tile.Background {
        var json = #"{ "type": "cli", "command": "ls""#
        if !panel.isEmpty { json += ", " + panel }
        json += " }"
        var entry = #"{ "panel": "x""#
        if !ref.isEmpty { entry += ", " + ref }
        entry += " }"
        let config = try load([
            "config.json": "{ \"panels\": [\(entry)] }",
            "panels/x/panel.json": json,
        ]).config
        return config.tiles[0].background
    }

    @Test func backgroundDefaultsToSame() throws {
        #expect(try background() == .same)
        #expect(try background(#""background": true"#) == .same)
        #expect(try background(#""background": false"#) == .off)
        #expect(try background(#""background": "5m""#) == .every(300))
    }

    @Test func panelEntryWinsOverThePanel() throws {
        #expect(try background(#""background": "5m""#, #""background": false"#) == .off)
        #expect(try background(#""background": false"#, #""background": "30s""#) == .every(30))
    }

    @Test func backgroundErrors() {
        func error(_ value: String) -> [String] {
            errors([
                "config.json": #"{ "panels": [{ "panel": "x" }] }"#,
                "panels/x/panel.json": #"{ "type": "cli", "command": "ls", "background": "# + value + " }",
            ])
        }
        #expect(error(#""soon""#) == [#"panels/x/panel.json: background: can't read "soon", write it like "30s", "5m" or "1h""#])
        #expect(error(#""1s""#) == [#"panels/x/panel.json: background: must be at least 5s, got "1s""#])
        #expect(error("3") == [#"panels/x/panel.json: background: expected a duration like "5m", true or false"#])
    }

    @Test func backgroundOnAStreamPanelIsAWarning() throws {
        let loaded = try load([
            "config.json": #"{ "panels": [{ "panel": "x" }] }"#,
            "panels/x/panel.json": #"{ "type": "cli", "command": "ls", "mode": "stream", "background": "5m" }"#,
        ])
        #expect(loaded.config.tiles.count == 1)
        #expect(loaded.warnings.map(\.description) == ["panels/x/panel.json: background: only applies to interval panels that run a command"])
    }

    @Test func hiddenPanelsRunWithoutASpot() throws {
        let loaded = try load([
            "config.json": #"{ "menuBar": "x", "panels": [{ "panel": "x", "show": false }, { "panel": "y", "size": "xl" }, { "panel": "y", "size": "xl" }] }"#,
            "panels/x/panel.json": #"{ "type": "cli", "command": "ls" }"#,
            "panels/y/panel.json": #"{ "type": "cli", "command": "pwd" }"#,
        ])
        #expect(loaded.config.tiles[0].show == false)
        #expect(loaded.config.tiles[0].slot == nil)
        #expect(loaded.config.tiles[1].slot != nil)
        #expect(loaded.config.tiles[2].slot != nil)
        #expect(loaded.warnings.isEmpty)
    }

    @Test func hiddenPanelThatNeverRunsIsAWarning() throws {
        let loaded = try load([
            "config.json": #"{ "panels": [{ "panel": "x", "show": false, "background": false }] }"#,
            "panels/x/panel.json": #"{ "type": "cli", "command": "ls" }"#,
        ])
        #expect(loaded.warnings.map(\.description) == [#"config.json: panels[0].show: "x" is hidden and doesn't run in the background, so it never runs"#])
    }

    // MARK: Notifications

    /// A panel's `notify`, with `panel.json`'s and the entry's extra keys.
    private func notify(_ panel: String = "", _ ref: String = "") throws -> NotifySettings? {
        var json = #"{ "type": "cli", "command": "ls""#
        if !panel.isEmpty { json += ", " + panel }
        json += " }"
        var entry = #"{ "panel": "x""#
        if !ref.isEmpty { entry += ", " + ref }
        entry += " }"
        let config = try load([
            "config.json": "{ \"panels\": [\(entry)] }",
            "panels/x/panel.json": json,
        ]).config
        return config.tiles[0].notify
    }

    @Test func notificationsDefaults() throws {
        #expect(try load(["config.json": "{}"]).config.notifications == NotificationSettings())
        #expect(try notify() == NotifySettings())
    }

    @Test func quietHours() throws {
        let config = try load(["config.json": #"{ "notifications": { "quietHours": "22:00-07:00" } }"#]).config
        #expect(config.notifications.quietHours == QuietHours(start: 1320, end: 420))
        #expect(errors(["config.json": #"{ "notifications": { "quietHours": "10pm" } }"#])
            == [#"config.json: notifications.quietHours: can't read "10pm", write it like "22:00-07:00""#])
    }

    @Test func notifyMerges() throws {
        #expect(try notify(#""notify": false"#) == nil)
        #expect(try notify(#""notify": { "minInterval": "1m", "on": ["failed"] }"#, #""notify": { "sound": false }"#)
            == NotifySettings(sound: false, minInterval: 60, on: [.failed]))
        #expect(try notify(#""notify": false"#, #""notify": true"#) == NotifySettings())
    }

    @Test func notifyErrors() {
        func error(_ value: String) -> [String] {
            errors([
                "config.json": #"{ "panels": [{ "panel": "x" }] }"#,
                "panels/x/panel.json": #"{ "type": "cli", "command": "ls", "notify": "# + value + " }",
            ])
        }
        #expect(error("3") == ["panels/x/panel.json: notify: expected true, false or an object"])
        #expect(error(#"{ "on": ["fail"] }"#) == [#"panels/x/panel.json: notify.on[0]: unknown event "fail", expected "failed", "warning" or "error""#])
        #expect(error(#"{ "minInterval": "soon" }"#) == [#"panels/x/panel.json: notify.minInterval: can't read "soon", write it like "30s", "5m" or "1h""#])
    }

    @Test func pauseDefaultsToBoth() throws {
        #expect(try load(["config.json": "{}"]).config.pause == Config.Pause())
        #expect(try load(["config.json": #"{ "pause": { "onLowPower": false } }"#]).config.pause
            == Config.Pause(whenLocked: true, onLowPower: false))
    }
}
