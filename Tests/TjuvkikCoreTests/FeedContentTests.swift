import Foundation
import Testing
@testable import TjuvkikCore

struct FeedContentTests {
    private func feed(_ text: String) throws -> FeedContent {
        guard case .feed(let feed) = try ScriptOutput.content(Data(text.utf8), as: .feed).get() else {
            throw ScriptOutputError(message: "not a feed")
        }
        return feed
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Monday 16 November 2026, 14:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_794_837_600)

    private func at(_ text: String) -> Date {
        FeedTime.date(from: text, timeZone: TimeZone(identifier: "UTC")!)!
    }

    @Test func nowIsMonday() {
        #expect(at("2026-11-16T14:00:00Z") == now)
    }

    @Test func everyField() throws {
        let content = try feed("""
        { "items": [{ "author": "Sara Lind", "avatar": "https://x/sara.png", "icon": "🔔", "where": "#dsp-spark",
                      "text": "Can you look at the export PR?", "time": "2026-11-16T13:12:00Z", "unread": true, "url": "slack://x" }] }
        """)
        #expect(content.items == [.init(author: "Sara Lind", avatar: "https://x/sara.png", icon: "🔔", place: "#dsp-spark",
                                        text: "Can you look at the export PR?", time: at("2026-11-16T13:12:00Z"), unread: true, url: "slack://x")])
    }

    @Test func detectedByItemsWithAuthorOrText() throws {
        let byAuthor = try ScriptOutput.content(Data(#"{ "items": [{ "author": "a", "text": "b" }] }"#.utf8)).get()
        #expect(byAuthor.type == .feed)
        let byText = try ScriptOutput.content(Data(#"{ "items": [{ "text": "b" }] }"#.utf8)).get()
        #expect(byText.type == .feed)
    }

    @Test func itemsWithTitlesArentAFeed() throws {
        let content = try? ScriptOutput.content(Data(#"{ "items": [{ "title": "Freeze main", "state": "done" }] }"#.utf8)).get()
        #expect(content?.type != .feed)
    }

    @Test func textIsRequired() {
        #expect(ScriptOutput.content(Data(#"{ "items": [{ "author": "Sara" }] }"#.utf8)).failureMessage == #"missing "text" in items[0]"#)
        #expect(ScriptOutput.content(Data(#"{ "rows": [] }"#.utf8), as: .feed).failureMessage == #"missing "items""#)
    }

    @Test func lenientValues() throws {
        let content = try feed(#"{ "items": { "author": 42, "where": 7, "text": 3.5, "unread": 1, "time": 1794837600 } }"#)
        #expect(content.items == [.init(author: "42", place: "7", text: "3.5", time: now, unread: true)])
        #expect(try feed(#"{ "items": [{ "text": "a", "unread": "yes" }] }"#).items[0].unread)
        #expect(try feed(#"{ "items": [{ "text": "a", "unread": "nope" }] }"#).items[0].unread == false)
        #expect(try feed(#"{ "items": [{ "text": "a", "time": 1794837600000 }] }"#).items[0].time == now)
    }

    @Test func timeThatIsntADateIsShownAsIs() throws {
        let item = try feed(#"{ "items": [{ "text": "a", "time": "2h ago" }] }"#).items[0]
        #expect(item.time == nil)
        #expect(item.when(now: now, calendar: utc) == "2h ago")
    }

    @Test func readsIsoTimes() {
        #expect(FeedTime.date(from: "2026-11-16T15:00:00+01:00") == now)
        #expect(FeedTime.date(from: "2026-11-16T14:00:00.000Z") == now)
        let utc = TimeZone(identifier: "UTC")!
        #expect(FeedTime.date(from: "2026-11-16T14:00", timeZone: utc) == now)
        #expect(FeedTime.date(from: "2026-11-16 14:00:00", timeZone: utc) == now)
        #expect(FeedTime.date(from: "2026-11-16", timeZone: utc) == at("2026-11-16T00:00:00Z"))
        #expect(FeedTime.date(from: "soon") == nil)
    }

    @Test func relativeTimes() {
        func relative(_ text: String) -> String { FeedTime.relative(at(text), now: now, calendar: utc) }
        #expect(relative("2026-11-16T14:05:00Z") == "now")
        #expect(relative("2026-11-16T13:59:30Z") == "now")
        #expect(relative("2026-11-16T13:55:00Z") == "5m")
        #expect(relative("2026-11-16T13:00:00Z") == "1h")
        #expect(relative("2026-11-16T00:30:00Z") == "13h")
        #expect(relative("2026-11-15T20:00:00Z") == "yesterday")
        #expect(relative("2026-11-14T10:00:00Z") == "Sat")
        #expect(relative("2026-11-10T10:00:00Z") == "Tue")
        #expect(relative("2026-11-09T10:00:00Z") == "9 Nov")
        #expect(relative("2025-12-24T10:00:00Z") == "24 Dec 2025")
    }

    @Test func lateLastNightIsInHours() {
        let now = at("2026-11-16T02:00:00Z")
        #expect(FeedTime.relative(at("2026-11-15T23:00:00Z"), now: now, calendar: utc) == "3h")
        #expect(FeedTime.relative(at("2026-11-15T19:00:00Z"), now: now, calendar: utc) == "yesterday")
    }

    @Test func relativeTimesFollowTheCalendarsZone() {
        var stockholm = Calendar(identifier: .gregorian)
        stockholm.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        // 23:30 UTC on Sunday is already Monday in Stockholm, so it's today there.
        #expect(FeedTime.dayTitle(at("2026-11-15T23:30:00Z"), now: now, calendar: stockholm) == "Today")
        #expect(FeedTime.dayTitle(at("2026-11-15T23:30:00Z"), now: now, calendar: utc) == "Yesterday")
    }

    @Test func dayTitles() {
        func title(_ text: String) -> String { FeedTime.dayTitle(at(text), now: now, calendar: utc) }
        #expect(title("2026-11-16T00:00:00Z") == "Today")
        #expect(title("2026-11-17T09:00:00Z") == "Today")
        #expect(title("2026-11-15T23:59:00Z") == "Yesterday")
        #expect(title("2026-11-12T10:00:00Z") == "Thursday")
        #expect(title("2026-11-09T10:00:00Z") == "9 Nov")
        #expect(title("2024-02-29T10:00:00Z") == "29 Feb 2024")
    }

    @Test func newestFirstWhenEveryItemHasATime() throws {
        let content = try feed("""
        { "items": [{ "text": "old", "time": "2026-11-15T10:00:00Z" }, { "text": "new", "time": "2026-11-16T13:00:00Z" },
                    { "text": "tie a", "time": "2026-11-16T12:00:00Z" }, { "text": "tie b", "time": "2026-11-16T12:00:00Z" }] }
        """)
        #expect(content.newestFirst.map(\.text) == ["new", "tie a", "tie b", "old"])
        #expect(content.items.map(\.text) == ["old", "new", "tie a", "tie b"])
    }

    @Test func scriptsOrderWhenATimeIsMissing() throws {
        let content = try feed(#"{ "items": [{ "text": "a", "time": "2026-11-15T10:00:00Z" }, { "text": "b" }] }"#)
        #expect(content.newestFirst.map(\.text) == ["a", "b"])
    }

    @Test func newestAndMoreUnread() throws {
        let content = try feed("""
        { "items": [{ "text": "a", "time": "2026-11-16T10:00:00Z", "unread": true }, { "text": "b", "time": "2026-11-16T13:00:00Z", "unread": true },
                    { "text": "c", "time": "2026-11-16T09:00:00Z" }, { "text": "d", "time": "2026-11-16T08:00:00Z", "unread": true }] }
        """)
        #expect(content.newest?.text == "b")
        #expect(content.moreUnread == 2)
        #expect(FeedContent(items: []).newest == nil)
        #expect(FeedContent(items: []).moreUnread == 0)
    }

    @Test func groupedByDay() throws {
        let content = try feed("""
        { "items": [{ "text": "a", "time": "2026-11-16T13:00:00Z" }, { "text": "b", "time": "2026-11-16T09:00:00Z" },
                    { "text": "c", "time": "2026-11-15T09:00:00Z" }, { "text": "d", "time": "2026-11-01T09:00:00Z" }] }
        """)
        let days = content.days(now: now, calendar: utc)
        #expect(days.map(\.title) == ["Today", "Yesterday", "1 Nov"])
        #expect(days.map { $0.items.map(\.text) } == [["a", "b"], ["c"], ["d"]])
    }

    @Test func undatedItemsStayInTheDayAbove() throws {
        let content = try feed(#"{ "items": [{ "text": "a" }, { "text": "b", "time": "2026-11-16T13:00:00Z" }, { "text": "c" }] }"#)
        let days = content.days(now: now, calendar: utc)
        #expect(days.map(\.title) == [nil, "Today"])
        #expect(days.map { $0.items.map(\.text) } == [["a"], ["b", "c"]])
    }

    @Test func initials() {
        #expect(FeedAuthor.initials("Sara Lind") == "SL")
        #expect(FeedAuthor.initials("Anton Ödman") == "AÖ")
        #expect(FeedAuthor.initials("anna maria berg") == "AB")
        #expect(FeedAuthor.initials("Azure") == "Az")
        #expect(FeedAuthor.initials("CI") == "CI")
        #expect(FeedAuthor.initials("@anton") == "An")
        #expect(FeedAuthor.initials("x") == "X")
        #expect(FeedAuthor.initials("🤖") == "🤖")
        #expect(FeedAuthor.initials("  ") == "?")
    }

    @Test func colorIsStableAndIgnoresCase() {
        // FNV-1a of the lowercased name, mod 5.
        #expect(FeedAuthor.colorIndex("Sara Lind", count: 5) == 4)
        #expect(FeedAuthor.colorIndex("Anton Ödman", count: 5) == 3)
        #expect(FeedAuthor.colorIndex("Kristian Ek", count: 5) == 2)
        #expect(FeedAuthor.colorIndex("Azure", count: 5) == 1)
        #expect(FeedAuthor.colorIndex("SARA LIND", count: 5) == FeedAuthor.colorIndex("sara lind", count: 5))
        #expect(FeedAuthor.colorIndex("Sara", count: 0) == 0)
        #expect(FeedAuthor.tone("Sara Lind") == .error)
        #expect(FeedAuthor.tone("Azure") == .info)
    }
}
