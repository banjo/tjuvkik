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
        #expect(config.holdMilliseconds == 250)
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
            #"panels/gh/panel.json: type: unknown type "web", expected one of "script", "cli", "stats""#,
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
}
