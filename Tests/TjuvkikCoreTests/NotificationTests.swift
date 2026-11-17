import Foundation
import Testing
@testable import TjuvkikCore

struct QuietHoursTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func at(_ hour: Int, _ minute: Int) -> Date {
        Date(timeIntervalSince1970: Double(hour * 3600 + minute * 60))
    }

    @Test func parses() {
        #expect(QuietHours.parse("22:00-07:00") == QuietHours(start: 1320, end: 420))
        #expect(QuietHours.parse(" 9:30 - 17:00 ") == QuietHours(start: 570, end: 1020))
        for text in ["10pm", "25:00-07:00", "22:00", "08:00-08:00"] {
            #expect(QuietHours.parse(text) == nil)
        }
    }

    @Test func containsAcrossMidnight() throws {
        let hours = try #require(QuietHours.parse("22:00-07:00"))
        #expect(hours.contains(at(23, 30), calendar: utc))
        #expect(hours.contains(at(6, 59), calendar: utc))
        #expect(!hours.contains(at(7, 0), calendar: utc))
        #expect(!hours.contains(at(12, 0), calendar: utc))
    }

    @Test func containsWithinADay() throws {
        let hours = try #require(QuietHours.parse("09:00-17:00"))
        #expect(hours.contains(at(9, 0), calendar: utc))
        #expect(!hours.contains(at(17, 0), calendar: utc))
    }
}

struct PanelNotificationsTests {
    private let script = PanelNotification(id: "a", title: "A")

    private func rows(_ rows: [RowsContent.Row], notify: [PanelNotification] = []) -> ModuleContent {
        var content = RowsContent(rows: rows)
        content.notify = notify
        return .rows(content)
    }

    @Test func scriptNotifyOnly() {
        let content = rows([.init(title: "x", tone: .warning)], notify: [script])
        #expect(PanelNotifications.collect(content: content, error: nil, title: "Pods", on: []) == [script])
    }

    @Test func failedWhileThereIsAnError() {
        #expect(PanelNotifications.collect(content: nil, error: "exit 1", title: "Pods", on: [.failed])
            == [PanelNotification(id: "tjuvkik:failed", title: "Pods failed", body: "exit 1")])
        #expect(PanelNotifications.collect(content: nil, error: nil, title: "Pods", on: [.failed]) == [])
    }

    @Test func rowsWithTheTone() {
        let content = rows([
            .init(title: "w", subtitle: "sub", tone: .warning, note: "note", url: "https://x"),
            .init(title: "s", subtitle: "sub", tone: .warning),
            .init(title: "e", tone: .error),
        ])
        let result = PanelNotifications.collect(content: content, error: nil, title: "Pods", on: [.warning])
        #expect(result.map(\.title) == ["w", "s"])
        #expect(result[0] == PanelNotification(id: "tjuvkik:row:warning:w\u{1F}sub", title: "w", subtitle: "Pods", body: "note", url: "https://x"))
        #expect(result[1].body == "sub")
    }

    @Test func duplicateIDKeepsTheFirst() {
        let content = rows([], notify: [script, PanelNotification(id: "a", title: "Again")])
        #expect(PanelNotifications.collect(content: content, error: nil, title: "Pods", on: []) == [script])
    }
}

struct NotificationPlannerTests {
    private func note(_ id: String) -> PanelNotification { PanelNotification(id: id, title: id.uppercased()) }
    private func at(_ seconds: Double) -> Date { Date(timeIntervalSince1970: seconds) }

    private func update(_ planner: inout NotificationPlanner, _ ids: [String], at seconds: Double = 0, muted: Bool = false, minInterval: Double = 0) -> [NotificationPlanner.Action] {
        planner.update(ids.map(note), now: at(seconds), muted: muted, minInterval: minInterval, panelTitle: "Pods")
    }

    @Test func deliversNewAndWithdrawsGone() {
        var planner = NotificationPlanner()
        #expect(update(&planner, ["a"]) == [])
        #expect(update(&planner, ["a", "b"]) == [.deliver(note("b"))])
        #expect(planner.deliveredIDs == ["b"])
        #expect(update(&planner, ["b"]) == [])
        #expect(update(&planner, []) == [.withdraw(id: "b")])
        #expect(planner.deliveredIDs == [])
    }

    @Test func mutedIsDropped() {
        var planner = NotificationPlanner()
        #expect(update(&planner, []) == [])
        #expect(update(&planner, ["a"], muted: true) == [])
        #expect(update(&planner, ["a"]) == [])
    }

    @Test func minIntervalGroups() {
        var planner = NotificationPlanner()
        #expect(update(&planner, [], minInterval: 60) == [])
        #expect(update(&planner, ["a"], at: 0, minInterval: 60) == [.deliver(note("a"))])
        #expect(update(&planner, ["a", "b", "c"], at: 10, minInterval: 60) == [])
        #expect(planner.flush(now: at(30), minInterval: 60, panelTitle: "Pods") == [])
        #expect(planner.flush(now: at(60), minInterval: 60, panelTitle: "Pods")
            == [.deliver(PanelNotification(id: "tjuvkik:group:1", title: "Pods", body: "2 new: B, C"))])
    }

    @Test func goneWhileWaitingIsDropped() {
        var planner = NotificationPlanner()
        _ = update(&planner, [], minInterval: 60)
        #expect(update(&planner, ["a"], at: 0, minInterval: 60) == [.deliver(note("a"))])
        #expect(update(&planner, ["a", "b"], at: 10, minInterval: 60) == [])
        #expect(update(&planner, ["a"], at: 20, minInterval: 60) == [])
        #expect(planner.flush(now: at(60), minInterval: 60, panelTitle: "Pods") == [])
    }

    @Test func noIntervalDeliversAll() {
        var planner = NotificationPlanner()
        _ = update(&planner, ["a"])
        #expect(update(&planner, ["a", "b", "c"]) == [.deliver(note("b")), .deliver(note("c"))])
    }

    @Test func waitingIsLimited() throws {
        var planner = NotificationPlanner()
        _ = update(&planner, [], minInterval: 60)
        #expect(update(&planner, ["a"], at: 0, minInterval: 60) == [.deliver(note("a"))])
        #expect(update(&planner, ["a"] + (0..<60).map { "n\($0)" }, at: 1, minInterval: 60) == [])
        let actions = planner.flush(now: at(60), minInterval: 60, panelTitle: "Pods")
        #expect(actions.count == 1)
        guard case .deliver(let group) = try #require(actions.first) else { Issue.record("not a delivery"); return }
        #expect(group.body?.hasPrefix("50 new: ") == true)
    }
}
