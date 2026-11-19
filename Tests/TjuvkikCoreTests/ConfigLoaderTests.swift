import Foundation
import Testing
@testable import TjuvkikCore

struct ConfigLoaderTests {
    @Test func defaultFilesLoadWithoutWarnings() throws {
        let fixture = ConfigFixture([:])
        try DefaultConfig.write(to: fixture.directory)
        let loaded = try fixture.load().get()
        #expect(loaded.warnings.isEmpty)
        #expect(loaded.config.darkTheme == .darkGlass)
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
        #expect(try fixture.load().get().config.darkTheme == .dracula)
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
        #expect(config.darkTheme == .dracula)
    }

    @Test func jsoncWinsOverJSONWithAWarning() throws {
        let loaded = try load(["config.jsonc": #"{ "theme": "dracula" }"#, "config.json": #"{ "theme": "light-glass" }"#])
        #expect(loaded.config.darkTheme == .dracula)
        #expect(loaded.warnings.map(\.description) == ["config.json: ignored, because config.jsonc exists"])
    }

    @Test func themeDefaultsToDarkGlass() throws {
        let config = try load(["config.json": "{}"]).config
        #expect(config.lightThemeName == "dark-glass")
        #expect(config.darkThemeName == "dark-glass")
        #expect(config.lightTheme == .darkGlass)
        #expect(config.darkTheme == .darkGlass)
    }

    @Test func oneThemeForBoth() throws {
        let config = try load(["config.json": #"{ "theme": "dracula" }"#]).config
        #expect(config.lightTheme == .dracula)
        #expect(config.darkTheme == .dracula)
    }

    @Test func themeForLightAndForDark() throws {
        let config = try load(["config.json": #"{ "theme": { "light": "light-glass", "dark": "dracula" } }"#]).config
        #expect(config.theme(dark: false) == .lightGlass)
        #expect(config.theme(dark: true) == .dracula)
        #expect(config.themeName(dark: false) == "light-glass")
        #expect(config.themeName(dark: true) == "dracula")
    }

    @Test func themePairNeedsBoth() {
        #expect(errors(["config.json": #"{ "theme": { "light": "light-glass" } }"#]) == [#"config.json: theme: set both "light" and "dark""#])
        let unknown = errors(["config.json": #"{ "theme": { "light": "light-glass", "dark": "nope" } }"#])
        #expect(unknown.count == 1)
        #expect(unknown.first?.hasPrefix(#"config.json: theme.dark: unknown theme "nope""#) == true)
    }

    @Test func emptyConfigGetsDefaults() throws {
        let config = try load(["config.json": "{}"]).config
        #expect(config.trigger == .fn)
        #expect(config.launchAtLogin)
        #expect(config.tiles.isEmpty)
        #expect(config.grid == .standard)
        #expect(config.zoom == .auto)
    }

    @Test func gridAndZoom() throws {
        let config = try load(["config.json": #"{ "grid": "6x4", "zoom": 1.25 }"#]).config
        #expect(config.grid == BoardGrid(columns: 6, rows: 4))
        #expect(config.zoom == .fixed(1.25))
        #expect(try load(["config.json": #"{ "zoom": "auto" }"#]).config.zoom == .auto)
    }

    @Test func badGridAndZoom() {
        #expect(errors(["config.json": #"{ "grid": "4x2" }"#]) == [#"config.json: grid: expected columns x rows, like "6x4", with 2–8 columns and 3–6 rows, got "4x2""#])
        #expect(errors(["config.json": #"{ "zoom": 3 }"#]) == ["config.json: zoom: must be between 0.75 and 2.0"])
        #expect(errors(["config.json": #"{ "zoom": "big" }"#]) == [#"config.json: zoom: expected "auto" or a number, got "big""#])
    }

    @Test func dimAndFocusOnOpen() throws {
        let plain = try load(["config.json": "{}"]).config
        #expect(plain.dim == 0)
        #expect(plain.focusOnOpen == .urgent)
        #expect(try load(["config.json": #"{ "dim": true }"#]).config.dim == Config.defaultDim)
        #expect(try load(["config.json": #"{ "dim": false }"#]).config.dim == 0)
        #expect(try load(["config.json": #"{ "dim": 0.6 }"#]).config.dim == 0.6)
        #expect(try load(["config.json": #"{ "focusOnOpen": "last" }"#]).config.focusOnOpen == .last)
        #expect(errors(["config.json": #"{ "dim": 2 }"#]) == ["config.json: dim: must be between 0 and 1"])
        #expect(errors(["config.json": #"{ "focusOnOpen": "mouse" }"#]) == [#"config.json: focusOnOpen: unknown value "mouse", expected "urgent" or "last""#])
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
        #expect(config.darkTheme == .dracula)
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
            "config.json": #"{ "panels": [{ "panel": "pods", "size": "l" }, { "panel": "pods", "id": "pods2" }] }"#,
            "panels/pods/panel.json": #"{ "type": "cli", "command": "kubectl get pods", "size": "m" }"#,
        ]).config
        #expect(config.tiles.map(\.size) == [.l, .m])
        #expect(config.tiles[0].title == "pods")
    }

    @Test func tileIdDefaultsToThePanel() throws {
        let config = try load([
            "config.json": #"{ "panels": [{ "panel": "pods" }] }"#,
            "panels/pods/panel.json": #"{ "type": "cli", "command": "kubectl get pods" }"#,
        ]).config
        #expect(config.tiles[0].id == "pods")
    }

    @Test func samePanelTwiceWithIdsAndTitles() throws {
        let panels = #"[{ "panel": "pods", "id": "a", "title": "Pods A" }, { "panel": "pods", "id": "b" }]"#
        let pods = #"{ "type": "cli", "command": "kubectl get pods" }"#
        let loaded = try load(["config.json": #"{ "menuBar": "a", "panels": \#(panels) }"#, "panels/pods/panel.json": pods])
        #expect(loaded.config.tiles.map(\.id) == ["a", "b"])
        #expect(loaded.config.tiles.map(\.title) == ["Pods A", "pods"])
        #expect(loaded.warnings.isEmpty)
        #expect(errors(["config.json": #"{ "menuBar": "pods", "panels": \#(panels) }"#, "panels/pods/panel.json": pods])
            == [#"config.json: menuBar: "pods" isn't in panels"#])
    }

    @Test func tileIdErrors() {
        let pods = #"{ "type": "cli", "command": "kubectl get pods" }"#
        #expect(errors(["config.json": #"{ "panels": [{ "panel": "pods" }, { "panel": "pods" }] }"#, "panels/pods/panel.json": pods])
            == [#"config.json: panels[1]: "pods" is already on the board, give this one an "id""#])
        #expect(errors(["config.json": #"{ "panels": [{ "panel": "pods", "id": "x" }, { "panel": "pods", "id": "x" }] }"#, "panels/pods/panel.json": pods])
            == [#"config.json: panels[1].id: "x" is already used by panels[0]"#])
        #expect(errors(["config.json": #"{ "panels": [{ "panel": "pods", "id": "a b" }] }"#, "panels/pods/panel.json": pods])
            == [#"config.json: panels[0].id: "a b" can't be an id: use letters, digits, - and _"#])
    }

    static let ci = #"""
    { "type": "cli", "command": "echo", "options": {
        "repo": { "type": "string", "required": true }, "limit": { "type": "number", "default": 10 },
        "branch": { "type": "string", "enum": ["main", "release"], "default": "main" }, "drafts": { "type": "boolean" } } }
    """#

    private func ciTiles(_ panels: String) throws -> [Tile] {
        try load(["config.json": #"{ "panels": \#(panels) }"#, "panels/ci/panel.json": Self.ci]).config.tiles
    }

    private func ciErrors(_ options: String) -> [String] {
        errors(["config.json": #"{ "panels": [{ "panel": "ci", "options": \#(options) }] }"#, "panels/ci/panel.json": Self.ci])
    }

    private func optionErrors(_ options: String) -> [String] {
        errors(["config.json": #"{ "panels": [{ "panel": "ci" }] }"#, "panels/ci/panel.json": #"{ "type": "cli", "command": "echo", "options": \#(options) }"#])
    }

    @Test func optionsGetTheirDefaults() throws {
        let tile = try ciTiles(#"[{ "panel": "ci", "options": { "repo": "a/b" } }]"#)[0]
        #expect(tile.options == ["repo": .string("a/b"), "limit": .number(10), "branch": .string("main")])
        #expect(tile.declaredOptions.map(\.name) == ["branch", "drafts", "limit", "repo"])
    }

    @Test func optionValuesKeepTheirTypes() throws {
        let tile = try ciTiles(#"[{ "panel": "ci", "options": { "repo": "a/b", "limit": 1, "drafts": true } }]"#)[0]
        #expect(tile.options["limit"] == .number(1))
        #expect(tile.options["drafts"] == .bool(true))
    }

    @Test func eachTileHasItsOwnOptions() throws {
        let tiles = try ciTiles(#"[{ "panel": "ci", "id": "ci-a", "options": { "repo": "a/a" } }, { "panel": "ci", "id": "ci-b", "options": { "repo": "b/b" } }]"#)
        #expect(tiles.map { $0.options["repo"] } == [.string("a/a"), .string("b/b")])
    }

    @Test func aPanelOnItsOwnNeedsNoRequiredOptions() throws {
        let fixture = ConfigFixture(["config.json": "{}", "panels/ci/panel.json": Self.ci])
        let tile = try ConfigLoader.panel("ci", in: fixture.directory).get()
        #expect(tile.options["repo"] == nil)
    }

    @Test func optionValueErrors() {
        #expect(errors(["config.json": #"{ "panels": [{ "panel": "ci" }] }"#, "panels/ci/panel.json": Self.ci])
            == [#"config.json: panels[0].options: missing "repo", which "ci" requires"#])
        #expect(ciErrors(#"{ "repo": "a/b", "repoo": "x" }"#)
            == [#"config.json: panels[0].options.repoo: "ci" has no option "repoo", expected one of "branch", "drafts", "limit", "repo""#])
        #expect(ciErrors(#"{ "repo": "a/b", "limit": "ten" }"#) == [#"config.json: panels[0].options.limit: expected a number, got "ten""#])
        #expect(ciErrors(#"{ "repo": "a/b", "drafts": "yes" }"#) == [#"config.json: panels[0].options.drafts: expected true or false, got "yes""#])
        #expect(ciErrors(#"{ "repo": ["a"] }"#) == [#"config.json: panels[0].options.repo: expected a string, got an array"#])
        #expect(ciErrors(#"{ "repo": "a/b", "branch": "dev" }"#) == [#"config.json: panels[0].options.branch: "dev" isn't one of "main", "release""#])
        #expect(errors([
            "config.json": #"{ "panels": [{ "panel": "pods", "options": { "x": 1 } }] }"#,
            "panels/pods/panel.json": #"{ "type": "cli", "command": "kubectl get pods" }"#,
        ]) == [#"config.json: panels[0].options.x: "pods" has no options"#])
    }

    @Test func optionDeclarationErrors() {
        #expect(optionErrors(#"{ "my repo": { "type": "string" } }"#)
            == [#"panels/ci/panel.json: options: "my repo" isn't an option name: start with a letter, then use letters, digits, - and _"#])
        #expect(optionErrors(#"{ "x": {} }"#)
            == [#"panels/ci/panel.json: options.x.type: missing "type", expected "string", "number" or "boolean""#])
        #expect(optionErrors(#"{ "x": { "type": "int" } }"#)
            == [#"panels/ci/panel.json: options.x.type: unknown type "int", expected "string", "number" or "boolean""#])
        #expect(optionErrors(#"{ "x": { "type": "number", "enum": ["a"] } }"#)
            == [#"panels/ci/panel.json: options.x.enum: only a string option can have enum"#])
        #expect(optionErrors(#"{ "x": { "type": "string", "enum": [] } }"#)
            == [#"panels/ci/panel.json: options.x.enum: can't be empty"#])
        #expect(optionErrors(#"{ "x": { "type": "number", "default": "ten" } }"#)
            == [#"panels/ci/panel.json: options.x.default: expected a number, got "ten""#])
        #expect(optionErrors(#"{ "x": { "type": "string", "enum": ["a"], "default": "b" } }"#)
            == [#"panels/ci/panel.json: options.x.default: "b" isn't one of "a""#])
        #expect(optionErrors(#"{ "my-repo": { "type": "string" }, "my_repo": { "type": "string" } }"#)
            == [#"panels/ci/panel.json: options.my_repo: "my-repo" already uses TJUVKIK_OPTION_MY_REPO"#])
    }

    @Test func requiredWithADefaultIsAWarning() throws {
        let loaded = try load([
            "config.json": #"{ "panels": [{ "panel": "ci" }] }"#,
            "panels/ci/panel.json": #"{ "type": "cli", "command": "echo", "options": { "x": { "type": "string", "required": true, "default": "a" } } }"#,
        ])
        #expect(loaded.warnings.map(\.description) == ["panels/ci/panel.json: options.x.required: it has a default, so it's never missing"])
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
            #"config.json: panels[0].size: unknown size "huge", expected columns x rows, like 2x1 (8 columns and 6 rows at most)"#,
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
            "config.json": #"{ "panels": [{ "panel": "x", "size": "xl" }, { "panel": "x", "id": "x2", "size": "xl" }, { "panel": "x", "id": "x3" }] }"#,
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
            "config.json": #"{ "menuBar": "x", "panels": [{ "panel": "x", "show": false }, { "panel": "y", "size": "xl" }, { "panel": "y", "id": "y2", "size": "xl" }] }"#,
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
