import Foundation
import Testing
@testable import TjuvkikCore

struct SpotlightSearchTests {
    let github = SpotlightPanel(tile: "github", title: "GitHub", typeName: "script", content: .rows(RowsContent(rows: [
        .init(icon: "🔀", title: "feat: export filters", subtitle: "logbook #1284", group: "Review", url: "https://example.com/1284"),
        .init(title: "fix: Calendar week numbers", subtitle: "calendar #77", group: "Mine"),
    ])))
    let disk = SpotlightPanel(tile: "disk", title: "Disk", typeName: "cli", content: .text("Filesystem  Size\n\n/dev/disk3s1  994Gi\n"))
    let chart = SpotlightPanel(tile: "latency", title: "Latency", typeName: "chart", content: nil)

    @Test func listsEveryPanelInOrder() {
        let sections = SpotlightSearch.sections([github, disk, chart], query: "")
        #expect(sections.map(\.tile) == ["github", "disk", "latency"])
        #expect(sections[0].items.map(\.title) == ["feat: export filters", "fix: Calendar week numbers"])
        #expect(sections[0].items[0].url == "https://example.com/1284")
        // Blank lines are left out.
        #expect(sections[1].items.map(\.title) == ["Filesystem  Size", "/dev/disk3s1  994Gi"])
    }

    @Test func aPanelWithNothingToListIsOneItem() {
        let items = SpotlightSearch.sections([chart], query: "")[0].items
        #expect(items.map(\.kind) == [.panel])
        #expect(items.map(\.title) == ["Latency"])
        #expect(items.map(\.subtitle) == ["chart"])
    }

    @Test func aPanelWithoutContentSaysWhy() {
        let loading = SpotlightPanel(tile: "jira", title: "Jira", typeName: "script", content: nil, status: "Loading…")
        #expect(SpotlightSearch.sections([loading], query: "")[0].items[0].subtitle == "Loading…")
        let empty = SpotlightPanel(tile: "jira", title: "Jira", typeName: "script", content: .rows(RowsContent(rows: [])))
        #expect(SpotlightSearch.sections([empty], query: "")[0].items[0].subtitle == "Nothing to show")
    }

    @Test func aLimitLeavesOutTheRestWithOneItemSayingHowMany() {
        let lines = SpotlightPanel(tile: "log", title: "Log", typeName: "cli", content: .text("1\n2\n3\n4\n5"))
        let items = SpotlightSearch.sections([lines], query: "", limit: 2)[0].items
        #expect(items.map(\.title) == ["1", "2", "3 more in Log"])
        #expect(items.last?.kind == .more(3))
        #expect(SpotlightSearch.sections([lines], query: "", limit: 2)[0].count == 5)
        // One more than the limit is shown rather than said.
        #expect(SpotlightSearch.sections([lines], query: "", limit: 4)[0].items.count == 5)
    }

    @Test func idsFollowTheRowNotItsPlace() {
        let before = SpotlightSearch.sections([github], query: "")[0].items
        var moved = github
        if case .rows(var rows) = moved.content {
            rows.rows.reverse()
            moved.content = .rows(rows)
        }
        let after = SpotlightSearch.sections([moved], query: "")[0].items
        #expect(after.map(\.id) == before.map(\.id).reversed())
        let same = SpotlightPanel(tile: "a", title: "A", typeName: "cli", content: .text("x\nx"))
        let ids = SpotlightSearch.sections([same], query: "")[0].items.map(\.id)
        #expect(Set(ids).count == 2)
    }

    @Test func everyWordMustMatchIgnoringCaseAndAccents() {
        #expect(SpotlightSearch.sections([github], query: "EXPORT 1284")[0].items.map(\.title) == ["feat: export filters"])
        #expect(SpotlightSearch.sections([github], query: "export calendar").isEmpty)
        let accented = SpotlightPanel(tile: "a", title: "A", typeName: "script", content: .rows(RowsContent(rows: [.init(title: "Café öppet")])))
        #expect(SpotlightSearch.sections([accented], query: "cafe oppet").count == 1)
    }

    @Test func matchesTheNoteAndDetails() {
        let rows = SpotlightPanel(tile: "a", title: "A", typeName: "script", content: .rows(RowsContent(rows: [.init(title: "x", note: "Bash: rm -rf")])))
        #expect(SpotlightSearch.sections([rows], query: "bash").count == 1)
    }

    @Test func matchesTheGroupAndThePanelTitle() {
        #expect(SpotlightSearch.sections([github], query: "review")[0].items.count == 1)
        #expect(SpotlightSearch.sections([github, disk], query: "github").map(\.tile) == ["github"])
        #expect(SpotlightSearch.sections([github, disk, chart], query: "latency").map(\.tile) == ["latency"])
    }

    @Test func aTailIsListedNewestFirst() {
        let items = SpotlightSearch.items(.tail("one\ntwo\nthree"), tile: "log")
        #expect(items.map(\.title) == ["three", "two", "one"])
    }

    @Test func checklistTasksKeepTheirSection() {
        let checklist = ChecklistContent(items: [.section("Release"), .task(.init(title: "Tag", state: .done, who: "anton"))])
        let items = SpotlightSearch.items(.checklist(checklist), tile: "release")
        #expect(items == [SpotlightItem(tile: "release", title: "Tag", subtitle: "anton", trailing: "done", group: "Release",
                                        details: [.init("Status", "done"), .init("Who", "anton")])])
    }

    @Test func tableRowsTakeTheirFirstCellAsTitle() {
        let table = TableContent(columns: [.init(title: "Pod"), .init(title: "Status")], rows: [
            .init(cells: [.init("api-7f9"), .init("CrashLoop")], highlight: .error, command: "kubectl logs api-7f9"),
        ])
        let items = SpotlightSearch.items(.table(table), tile: "pods")
        #expect(items == [SpotlightItem(tile: "pods", title: "api-7f9", subtitle: "CrashLoop", tone: .error,
                                        details: [.init("Status", "CrashLoop")], command: "kubectl logs api-7f9")])
    }
}
