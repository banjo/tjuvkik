import Foundation
import Testing
@testable import TjuvkikCore

private func load(_ text: String) -> Result<LoadedConfig, ConfigErrors> {
    ConfigLoader.parse(Data(text.utf8))
}

private func errors(_ text: String) -> [String] {
    guard case .failure(let errors) = load(text) else { return [] }
    return errors.issues.map(\.description)
}

private func config(_ text: String) throws -> LoadedConfig {
    try load(text).get()
}

struct ConfigLoaderTests {
    @Test func defaultConfigLoadsWithoutWarnings() throws {
        let loaded = try config(DefaultConfig.text)
        #expect(loaded.warnings.isEmpty)
        #expect(loaded.config.theme == .darkGlass)
        #expect(loaded.config.tiles.map(\.title) == ["Agents", "Disk"])
        #expect(loaded.config.tiles[1].kind == .cli(command: "df -h /"))
        #expect(loaded.config.tiles[1].every == 300)
    }

    @Test func emptyObjectGetsDefaults() throws {
        let loaded = try config("{}")
        #expect(loaded.config.holdMilliseconds == 250)
        #expect(loaded.config.launchAtLogin)
        #expect(loaded.config.tiles.map(\.kind) == [.agents])
    }

    @Test func commentsAndTrailingCommas() throws {
        let loaded = try config("""
        {
          // a comment
          "theme": "dracula", /* another */
          "tiles": [{ "module": "agents", "size": "l", },],
        }
        """)
        #expect(loaded.config.theme == .dracula)
        #expect(loaded.config.tiles[0].size == .l)
    }

    @Test func laterValuesFallBackWithAWarning() throws {
        let loaded = try config(#"{ "view": "spotlight", "layout": "edges" }"#)
        #expect(loaded.config.view == .bento)
        #expect(loaded.config.layout == .framed)
        #expect(loaded.warnings.map(\.path) == ["view", "layout"])
    }

    @Test func syntaxErrorIsReported() {
        let issues = errors(#"{ "theme": "dracula" "view": "bento" }"#)
        #expect(issues.count == 1)
    }

    @Test func wrongTypeHasAPath() {
        #expect(errors(#"{ "tiles": [{ "module": "agents", "size": 3 }] }"#) == ["tiles[0].size: expected a string"])
    }

    @Test func everyProblemIsReported() {
        let issues = errors("""
        { "theme": "nope", "tiles": [
          { "type": "cli", "title": "Pods", "size": "huge", "every": "soon" },
          { "module": "weather" },
        ] }
        """)
        #expect(issues == [
            #"theme: unknown theme "nope", expected one of "dark-glass", "dracula", "light-glass""#,
            "tiles[0].command: a cli tile needs a command",
            #"tiles[0].size: unknown size "huge", expected "s", "m", "l" or "xl""#,
            #"tiles[0].every: can't read "soon", write it like "30s", "5m" or "1h""#,
            #"tiles[1].module: unknown module "weather", expected "agents""#,
        ])
    }

    @Test func intervalHasAMinimum() {
        #expect(errors(#"{ "tiles": [{ "type": "cli", "title": "x", "command": "ls", "every": "1s" }] }"#)
            == [#"tiles[0].every: must be at least 5s, got "1s""#])
    }

    @Test func tilesThatDontFitAreWarnedAndLeftOut() throws {
        let loaded = try config(#"{ "tiles": [{ "module": "agents", "size": "xl" }, { "module": "agents", "size": "xl" }, { "module": "agents" }] }"#)
        #expect(loaded.config.tiles.map(\.slot) == [
            GridSlot(column: 0, row: 0, columns: 2, rows: 3),
            GridSlot(column: 2, row: 0, columns: 2, rows: 3),
            nil,
        ])
        #expect(loaded.warnings.map(\.path) == ["tiles[2]"])
    }

    @Test func holdMsRange() {
        #expect(errors(#"{ "trigger": { "holdMs": 10 } }"#) == ["trigger.holdMs: must be between 50 and 2000, got 10"])
    }
}
