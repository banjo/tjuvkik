import Foundation
import Testing
@testable import TjuvkikCore

struct PanelOptionsTests {
    @Test func valuesAsText() {
        #expect(OptionValue.number(10).text == "10")
        #expect(OptionValue.number(2.5).text == "2.5")
        #expect(OptionValue.number(-3).text == "-3")
        #expect(OptionValue.bool(false).text == "false")
    }

    @Test func variableName() {
        #expect(PanelOption(name: "my-repo", kind: .string).variable == "TJUVKIK_OPTION_MY_REPO")
    }

    @Test func json() {
        #expect(PanelOptions.json(["repo": .string("a/b"), "limit": .number(10), "x": .bool(true)]) == #"{"limit":10,"repo":"a\/b","x":true}"#)
    }

    @Test func environment() throws {
        let fixture = ConfigFixture([
            "config.json": #"{ "panels": [{ "panel": "ci", "id": "ci-a", "options": { "repo": "a/b" } }] }"#,
            "panels/ci/panel.json": #"{ "type": "cli", "command": "echo", "options": { "repo": { "type": "string" }, "limit": { "type": "number", "default": 10 } } }"#,
        ])
        let tile = try fixture.load().get().config.tiles[0]
        let environment = PanelOptions.environment(["PATH": "/bin", "TJUVKIK_OPTION_OLD": "x"], for: tile)
        #expect(environment == [
            "PATH": "/bin",
            "TJUVKIK_PANEL": "ci",
            "TJUVKIK_ID": "ci-a",
            "TJUVKIK_OPTION_REPO": "a/b",
            "TJUVKIK_OPTION_LIMIT": "10",
            "TJUVKIK_OPTIONS": #"{"limit":10,"repo":"a\/b"}"#,
        ])
    }

    @Test func parse() {
        #expect(PanelOptions.parse("5", as: PanelOption(name: "n", kind: .number)) == .success(.number(5)))
        #expect(PanelOptions.parse("ten", as: PanelOption(name: "n", kind: .number)) == .failure(OptionError(#"expected a number, got "ten""#)))
        #expect(PanelOptions.parse("true", as: PanelOption(name: "b", kind: .boolean)) == .success(.bool(true)))
        #expect(PanelOptions.parse("yes", as: PanelOption(name: "b", kind: .boolean)) == .failure(OptionError(#"expected true or false, got "yes""#)))
        #expect(PanelOptions.parse("dev", as: PanelOption(name: "s", kind: .string, choices: ["main"])) == .failure(OptionError(#""dev" isn't one of "main""#)))
    }
}
