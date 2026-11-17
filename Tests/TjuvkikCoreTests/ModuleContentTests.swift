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

    @Test func menuBarDefaultsToTheFirstSummaryChip() throws {
        let content = try parse(#"{ "summary": [{ "icon": "❓", "value": "2", "label": "waiting" }, { "icon": "⏳", "value": "1" }], "rows": [] }"#).get()
        #expect(content.menuBar?.title == "❓ 2")
        #expect(content.menuBar?.menu?.map(\.title) == ["❓ 2 waiting  ·  ⏳ 1"])
        #expect(try parse(#"{ "rows": [] }"#).get().menuBar == nil)
    }

    @Test func menuBarSetByThePanel() throws {
        let content = try parse(#"{ "menuBar": { "icon": "⇡", "text": "3", "tone": "info", "menu": [{ "title": "PR", "url": "https://x" }] }, "summary": [{ "value": "9" }], "rows": [] }"#).get()
        #expect(content.menuBar == .init(icon: "⇡", text: "3", tone: .info, menu: [.init(title: "PR", url: "https://x")]))
        #expect(try parse(#"{ "menuBar": null, "summary": [{ "value": "9" }], "rows": [] }"#).get().menuBar == nil)
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

struct ContentTypeTests {
    private func content(_ text: String, as type: ContentType? = nil) -> Result<ModuleContent, ScriptOutputError> {
        ScriptOutput.content(Data(text.utf8), as: type)
    }

    @Test func rowsByDefault() throws {
        let content = try content(#"{ "rows": [{ "title": "a" }] }"#).get()
        #expect(content == .rows(RowsContent(rows: [.init(title: "a")])))
        #expect(content.type == nil)
    }

    @Test func theTopLevelKeyPicksTheType() throws {
        #expect(try content(#"{ "stats": [{ "value": "1" }] }"#).get().type == .stats)
    }

    @Test func probeReadsTopLevelAndItemKeys() throws {
        let probe = try JSONDecoder().decode(KeyProbe.self, from: Data(#"{ "items": [{ "a": 1 }, { "b": 2 }, "x"], "c": null }"#.utf8))
        #expect(probe.keys == ["items", "c"])
        #expect(probe.itemKeys == ["a", "b"])
    }

    @Test func oneItemWithoutAnArrayIsDetectedToo() throws {
        #expect(try content(#"{ "items": { "author": "Sara", "text": "hi" } }"#).get().type == .feed)
        #expect(try content(#"{ "items": { "title": "Freeze main" } }"#).get().type == .checklist)
    }

    @Test func thePanelsTypeWins() {
        #expect(content(#"{ "rows": [] }"#, as: .stats).failureMessage == #"missing "stats""#)
    }

    @Test func summaryAndMenuBarWorkWithEveryType() throws {
        let content = try content(#"{ "stats": [{ "value": "1" }], "summary": [{ "icon": "❓", "value": "2" }] }"#).get()
        #expect(content.menuBar?.title == "❓ 2")
        let hidden = try self.content(#"{ "stats": [{ "value": "1" }], "summary": [{ "value": "2" }], "menuBar": null }"#).get()
        #expect(hidden.menuBar == nil)
    }

    @Test func notifyWithRows() throws {
        let content = try content(#"{ "rows": [], "notify": [{ "id": "a", "title": "A" }] }"#).get()
        #expect(content.notify == [PanelNotification(id: "a", title: "A")])
    }

    @Test func notifyWorksWithEveryType() throws {
        let content = try content(#"{ "stats": [{ "label": "x", "value": "1" }], "notify": [{ "id": "a", "title": "A", "url": "https://x" }] }"#).get()
        #expect(content.type == .stats)
        #expect(content.notify == [PanelNotification(id: "a", title: "A", url: "https://x")])
    }

    @Test func noNotifyIsEmpty() throws {
        #expect(try content(#"{ "rows": [] }"#).get().notify == [])
        #expect(try content(#"{ "stats": [{ "value": "1" }] }"#).get().notify == [])
    }

    @Test func notifyNeedsAnID() {
        #expect(content(#"{ "rows": [], "notify": [{ "title": "A" }] }"#).failureMessage == #"missing "id" in notify[0]"#)
    }
}

struct StatsContentTests {
    private func stats(_ text: String) throws -> StatsContent {
        guard case .stats(let stats) = try ScriptOutput.content(Data(text.utf8), as: .stats).get() else {
            throw ScriptOutputError(message: "not stats")
        }
        return stats
    }

    @Test func everyField() throws {
        let content = try stats(#"{ "stats": [{ "label": "Crash-free sessions", "value": "99.71", "unit": "%", "delta": "▼ 0.12", "tone": "error", "vs": "vs last week" }] }"#)
        #expect(content.stats == [.init(label: "Crash-free sessions", value: "99.71", unit: "%", delta: "▼ 0.12", tone: .error, vs: "vs last week")])
    }

    @Test func numbersReadAsText() throws {
        let content = try stats(#"{ "stats": [{ "value": 12, "delta": 0.5 }, { "value": 2.25 }] }"#)
        #expect(content.stats.map(\.value) == ["12", "2.25"])
        #expect(content.stats[0].delta == "0.5")
    }

    @Test func oneStatWithoutAnArray() throws {
        #expect(try stats(#"{ "stats": { "value": "3" } }"#).stats == [.init(value: "3")])
    }

    @Test func valueIsRequired() {
        #expect(ScriptOutput.content(Data(#"{ "stats": [{ "label": "x" }] }"#.utf8)).failureMessage == #"missing "value" in stats[0]"#)
    }
}

struct TerminalTextTests {
    @Test func stripsColorsAndCursorMoves() {
        #expect(TerminalText.clean("\u{1B}[1;32mRunning\u{1B}[0m  2/2\r\n") == "Running  2/2\n")
        #expect(TerminalText.clean("\u{1B}[?25lhidden\u{1B}[2K") == "hidden")
        #expect(TerminalText.clean("\u{1B}]8;;https://x\u{07}link\u{1B}]8;;\u{07}") == "link")
    }
}

extension Result where Failure == ScriptOutputError {
    var failureMessage: String? {
        if case .failure(let error) = self { return error.message }
        return nil
    }
}
