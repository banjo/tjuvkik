import Foundation
import Testing
@testable import TjuvkikCore

struct ScriptOutputTests {
    private func parse(_ text: String) -> Result<RowsContent, ScriptOutputError> {
        ScriptOutput.parse(Data(text.utf8))
    }

    @Test func fullOutput() throws {
        let content = try parse("""
        { "hero": { "value": "1", "label": "review requested", "tone": "warning" },
          "progress": 0.62,
          "rows": [{ "icon": "👀", "title": "Export bookings", "subtitle": "vgcs/logbook #1284", "trailing": "1h", "tone": "warning", "url": "https://x" }] }
        """).get()
        #expect(content.hero == .init(value: "1", label: "review requested", tone: .warning))
        #expect(content.progress == 0.62)
        #expect(content.rows[0].title == "Export bookings")
        #expect(content.rows[0].tone == .warning)
    }

    @Test func groupsNotesAndSummary() throws {
        let content = try parse("""
        { "summary": [{ "icon": "❓", "value": "2", "label": "waiting", "tone": "warning" }],
          "rows": [{ "title": "a", "group": "zellij · dotfiles", "note": "Bash: rm -rf node_modules" }] }
        """).get()
        #expect(content.summary == [.init(icon: "❓", value: "2", label: "waiting", tone: .warning)])
        #expect(content.rows[0].group == "zellij · dotfiles")
        #expect(content.rows[0].note == "Bash: rm -rf node_modules")
    }

    @Test func onlyRowsAreRequired() throws {
        let content = try parse(#"{ "rows": [{ "title": "a" }] }"#).get()
        #expect(content.hero == nil)
        #expect(content.rows.map(\.title) == ["a"])
    }

    @Test func unknownToneIsNormal() throws {
        #expect(try parse(#"{ "rows": [{ "title": "a", "tone": "sparkly" }] }"#).get().rows[0].tone == .normal)
    }

    @Test func progressIsClamped() throws {
        #expect(try parse(#"{ "progress": 3, "rows": [] }"#).get().progress == 1)
    }

    @Test func errorsSayWhatsWrong() {
        #expect(parse("").failureMessage == "printed nothing")
        #expect(parse("Error: not logged in").failureMessage == "didn't print JSON: Error: not logged in")
        #expect(parse(#"{ "hero": {} }"#).failureMessage == #"missing "value" in hero"#)
        #expect(parse(#"{ "rows": [{ "icon": "x" }] }"#).failureMessage == #"missing "title" in rows[0]"#)
        #expect(parse(#"{ "rows": "nope" }"#).failureMessage == "wrong type at rows")
    }
}

struct TerminalTextTests {
    @Test func stripsColorsAndCursorMoves() {
        #expect(TerminalText.clean("\u{1B}[1;32mRunning\u{1B}[0m  2/2\r\n") == "Running  2/2\n")
        #expect(TerminalText.clean("\u{1B}[?25lhidden\u{1B}[2K") == "hidden")
        #expect(TerminalText.clean("\u{1B}]8;;https://x\u{07}link\u{1B}]8;;\u{07}") == "link")
    }
}

private extension Result where Failure == ScriptOutputError {
    var failureMessage: String? {
        if case .failure(let error) = self { return error.message }
        return nil
    }
}
