import Foundation
import Testing
@testable import TjuvkikCore

struct ChecklistContentTests {
    private func checklist(_ text: String) throws -> ChecklistContent {
        guard case .checklist(let checklist) = try ScriptOutput.content(Data(text.utf8), as: .checklist).get() else {
            throw ScriptOutputError(message: "not a checklist")
        }
        return checklist
    }

    private static let release = #"""
    { "items": [
        { "section": "Before" },
        { "title": "Freeze main", "state": "done" },
        { "title": "Bump version", "state": "done" },
        { "title": "Smoke test QA", "state": "doing", "who": "Sara", "note": "export left" },
        { "title": "Sign-off", "state": "blocked", "note": "Waiting for PO" },
        { "section": "Release" },
        { "title": "Deploy", "who": "Anton" },
        { "section": "After" },
        { "title": "Old step", "state": "skipped" }
      ],
      "foldDone": true, "caption": "steps · release Thu 14:00" }
    """#

    @Test func everyField() throws {
        let content = try checklist(Self.release)
        #expect(content.items == [
            .section("Before"),
            .task(.init(title: "Freeze main", state: .done)),
            .task(.init(title: "Bump version", state: .done)),
            .task(.init(title: "Smoke test QA", state: .doing, who: "Sara", note: "export left")),
            .task(.init(title: "Sign-off", state: .blocked, note: "Waiting for PO")),
            .section("Release"),
            .task(.init(title: "Deploy", who: "Anton")),
            .section("After"),
            .task(.init(title: "Old step", state: .skipped)),
        ])
        #expect(content.foldDone)
        #expect(content.caption == "steps · release Thu 14:00")
    }

    @Test func detectedByItems() throws {
        let content = try ScriptOutput.content(Data(#"{ "items": [{ "title": "a" }] }"#.utf8)).get()
        #expect(content.type == .checklist)
        #expect(content == .checklist(ChecklistContent(items: [.task(.init(title: "a"))])))
    }

    @Test func feedItemsAreNotAChecklist() throws {
        let content = try ScriptOutput.content(Data(#"{ "items": [{ "author": "Sara", "text": "Hi" }] }"#.utf8)).get()
        #expect(content.type != .checklist)
    }

    @Test func titleIsRequired() {
        #expect(ScriptOutput.content(Data(#"{ "items": [{ "state": "done" }] }"#.utf8), as: .checklist).failureMessage == #"missing "title" in items[0]"#)
        #expect(ScriptOutput.content(Data(#"{ "rows": [] }"#.utf8), as: .checklist).failureMessage == #"missing "items""#)
    }

    @Test func unknownStatesAreTodo() throws {
        let content = try checklist(#"{ "items": [{ "title": "a", "state": "someday" }, { "title": "b", "state": " DONE " }, { "title": "c", "state": true }, { "title": "d", "state": false }] }"#)
        #expect(content.tasks.map(\.state) == [.todo, .done, .done, .todo])
    }

    @Test func numbersReadAsText() throws {
        let content = try checklist(#"{ "items": [{ "section": 2026 }, { "title": 42, "who": 7, "note": 1.5 }] }"#)
        #expect(content.items == [.section("2026"), .task(.init(title: "42", who: "7", note: "1.5"))])
    }

    @Test func aTitleWinsOverASection() throws {
        let content = try checklist(#"{ "items": [{ "section": "x", "title": "a" }] }"#)
        #expect(content.items == [.task(.init(title: "a"))])
    }

    @Test func foldDoneIsOffByDefault() throws {
        let content = try checklist(#"{ "items": [{ "title": "a", "state": "done" }] }"#)
        #expect(!content.foldDone)
        #expect(content.visibleItems == content.items)
        #expect(content.foldedLine == nil)
    }

    @Test func countsSkipSkipped() throws {
        let content = try checklist(Self.release)
        #expect(content.done == 2)
        #expect(content.doing == 1)
        #expect(content.skipped == 1)
        #expect(content.total == 5)
        #expect(content.count == "2/5")
        #expect(content.progress == 0.4)
        #expect(content.doingProgress == 0.2)
    }

    @Test func emptyHasNoProgress() {
        let content = ChecklistContent(items: [.section("a")])
        #expect(content.count == "0/0")
        #expect(content.progress == 0)
        #expect(content.next == nil)
        #expect(!content.isComplete)
    }

    @Test func nextIsTheFirstDoingElseTheFirstTodo() {
        let doing = ChecklistContent(items: [.task(.init(title: "a")), .task(.init(title: "b", state: .doing))])
        #expect(doing.next?.title == "b")
        let todo = ChecklistContent(items: [.task(.init(title: "a", state: .done)), .task(.init(title: "b", state: .blocked)), .task(.init(title: "c"))])
        #expect(todo.next?.title == "c")
        let stuck = ChecklistContent(items: [.task(.init(title: "a", state: .done)), .task(.init(title: "b", state: .blocked))])
        #expect(stuck.next == nil)
        #expect(!stuck.isComplete)
        let finished = ChecklistContent(items: [.task(.init(title: "a", state: .done)), .task(.init(title: "b", state: .skipped))])
        #expect(finished.isComplete)
    }

    @Test func foldingHidesDoneStepsAndEmptySections() throws {
        let content = try checklist(Self.release)
        #expect(content.visibleItems == [
            .section("Before"),
            .task(.init(title: "Smoke test QA", state: .doing, who: "Sara", note: "export left")),
            .task(.init(title: "Sign-off", state: .blocked, note: "Waiting for PO")),
            .section("Release"),
            .task(.init(title: "Deploy", who: "Anton")),
        ])
        #expect(content.foldedLine == "✓ 2 done · 1 skipped")
    }

    @Test func foldedLineOnlyWhenSomethingIsFolded() {
        #expect(ChecklistContent(items: [.task(.init(title: "a"))], foldDone: true).foldedLine == nil)
        #expect(ChecklistContent(items: [.task(.init(title: "a", state: .done))], foldDone: true).foldedLine == "✓ 1 done")
    }

    @Test func twoColumnsWhenOneIsntEnough() {
        #expect(ChecklistContent.columns(for: 3, rowsThatFit: 4) == 1)
        #expect(ChecklistContent.columns(for: 4, rowsThatFit: 4) == 1)
        #expect(ChecklistContent.columns(for: 6, rowsThatFit: 4) == 2)
        #expect(ChecklistContent.columns(for: 2, rowsThatFit: 0) == 2)
    }

    @Test func summaryAndMenuBarWork() throws {
        let content = try ScriptOutput.content(Data(#"{ "items": [{ "title": "a" }], "menuBar": { "text": "0/1" } }"#.utf8)).get()
        #expect(content.menuBar?.title == "0/1")
    }
}
