import Foundation
import Testing
@testable import TjuvkikCore

struct TimelineContentTests {
    /// UTC+1 without daylight saving, so the tests don't depend on the machine's zone.
    private static let fixedCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 3600)!
        return calendar
    }()

    private var calendar: Calendar { Self.fixedCalendar }

    /// 2026-11-16T00:00Z.
    private let midnightUTC: TimeInterval = 1_794_787_200

    private func timeline(_ text: String) throws -> TimelineContent {
        guard case .timeline(let timeline) = try ScriptOutput.content(Data(text.utf8), as: .timeline).get() else {
            throw ScriptOutputError(message: "not a timeline")
        }
        return timeline
    }

    /// A local time in the test calendar.
    private func at(_ text: String) -> Date {
        TimelineContent.Moment.parse(text)!.date(now: Date(timeIntervalSince1970: midnightUTC), calendar: calendar)!
    }

    private func moment(_ text: String) -> TimelineContent.Moment {
        TimelineContent.Moment.parse(text)!
    }

    /// The prototype's day, at 13:40.
    private var day: TimelineContent {
        TimelineContent(from: moment("09:00"), to: moment("17:00"), events: [
            .init(title: "Standup", start: moment("2026-11-16T09:15"), end: moment("2026-11-16T09:30"), tone: .info),
            .init(title: "Logbook export review", start: moment("2026-11-16T10:00"), end: moment("2026-11-16T11:00"), subtitle: "Room Kajen"),
            .init(title: "Lunch", start: moment("2026-11-16T11:30"), end: moment("2026-11-16T12:30"), tone: .muted),
            .init(title: "Focus time", start: moment("2026-11-16T13:00"), end: moment("2026-11-16T14:30"), subtitle: "no meetings", tone: .success),
            .init(title: "Sprint review", start: moment("2026-11-16T15:00"), end: moment("2026-11-16T16:00"), subtitle: "Teams"),
            .init(title: "1:1 Sara", start: moment("2026-11-16T16:15"), end: moment("2026-11-16T16:45"), tone: .warning),
        ])
    }

    // MARK: Parsing

    @Test func everyField() throws {
        let content = try timeline(#"""
        { "timeline": {
            "from": "09:00", "to": "17:00",
            "events": [{ "title": "Sprint review", "start": "2026-11-16T15:00", "end": "2026-11-16T16:00", "subtitle": "Teams",
                         "tone": "accent", "url": "https://example.com", "command": "open 'msteams://x'" }] } }
        """#)
        #expect(content.from == .clock(hour: 9, minute: 0))
        #expect(content.to == .clock(hour: 17, minute: 0))
        #expect(content.events == [.init(title: "Sprint review",
                                         start: .local(year: 2026, month: 11, day: 16, hour: 15, minute: 0, second: 0),
                                         end: .local(year: 2026, month: 11, day: 16, hour: 16, minute: 0, second: 0),
                                         subtitle: "Teams", tone: .accent, url: "https://example.com", command: "open 'msteams://x'")])
    }

    @Test func theTopLevelKeyPicksTimeline() throws {
        let content = try ScriptOutput.content(Data(#"{ "timeline": { "events": [] } }"#.utf8)).get()
        #expect(content.type == .timeline)
        #expect(content == .timeline(TimelineContent(events: [])))
    }

    @Test func justTheEvents() throws {
        let content = try timeline(#"{ "timeline": [{ "title": "Standup", "start": "09:15" }] }"#)
        #expect(content.from == nil && content.to == nil)
        #expect(content.events == [.init(title: "Standup", start: .clock(hour: 9, minute: 15))])
    }

    @Test func titlesAndSubtitlesMayBeNumbers() throws {
        let content = try timeline(#"{ "timeline": { "events": [{ "title": 42, "subtitle": 7, "start": "10:00" }] } }"#)
        #expect(content.events[0].title == "42")
        #expect(content.events[0].subtitle == "7")
    }

    @Test func unknownTonesReadAsNormal() throws {
        let content = try timeline(#"{ "timeline": { "events": [{ "title": "a", "start": "10:00", "tone": "sparkly" }] } }"#)
        #expect(content.events[0].tone == .normal)
    }

    @Test func requiredFields() {
        let messages = [
            #"{ "timeline": { "events": [{ "start": "10:00" }] } }"#,
            #"{ "timeline": { "events": [{ "title": "a" }] } }"#,
            #"{ "timeline": { "from": "09:00" } }"#,
            #"{ "timeline": [{ "title": "a" }] }"#,
        ].map { ScriptOutput.content(Data($0.utf8)).failureMessage }
        #expect(messages == [
            #"missing "title" in timeline.events[0]"#,
            #"missing "start" in timeline.events[0]"#,
            #"missing "events" in timeline"#,
            #"missing "start" in timeline[0]"#,
        ])
        #expect(ScriptOutput.content(Data(#"{ "rows": [] }"#.utf8), as: .timeline).failureMessage == #"missing "timeline""#)
    }

    @Test func unreadableTimesSayWhere() {
        #expect(ScriptOutput.content(Data(#"{ "timeline": { "events": [{ "title": "a", "start": "soon" }] } }"#.utf8)).failureMessage
            == "wrong type at timeline.events[0].start")
        #expect(ScriptOutput.content(Data(#"{ "timeline": { "to": "25:00", "events": [] } }"#.utf8)).failureMessage
            == "wrong type at timeline.to")
    }

    @Test func summaryAndMenuBarStillWork() throws {
        let content = try ScriptOutput.content(Data(#"{ "timeline": { "events": [] }, "summary": [{ "icon": "📅", "value": "3" }] }"#.utf8)).get()
        #expect(content.menuBar?.title == "📅 3")
    }

    // MARK: Times

    @Test func readsLocalTimes() {
        #expect(moment("2026-11-16T15:00") == .local(year: 2026, month: 11, day: 16, hour: 15, minute: 0, second: 0))
        #expect(moment("2026-11-16T15:00:30") == .local(year: 2026, month: 11, day: 16, hour: 15, minute: 0, second: 30))
        #expect(moment("2026-11-16 15:00:30.250") == .local(year: 2026, month: 11, day: 16, hour: 15, minute: 0, second: 30))
        #expect(moment(" 2026-11-16t9:05 ") == .local(year: 2026, month: 11, day: 16, hour: 9, minute: 5, second: 0))
        #expect(moment("2026-11-16") == .local(year: 2026, month: 11, day: 16, hour: 0, minute: 0, second: 0))
    }

    @Test func readsZonedTimesAsInstants() {
        let fifteenUTC = Date(timeIntervalSince1970: midnightUTC + 15 * 3600)
        #expect(moment("2026-11-16T15:00Z") == .instant(fifteenUTC))
        #expect(moment("2026-11-16T15:00:00.000Z") == .instant(fifteenUTC))
        #expect(moment("2026-11-16T16:00+01:00") == .instant(fifteenUTC))
        #expect(moment("2026-11-16T16:00+0100") == .instant(fifteenUTC))
        #expect(moment("2026-11-16T10:00-05") == .instant(fifteenUTC))
        #expect(moment("2026-11-16 16:00 +01:00") == .instant(fifteenUTC))
    }

    @Test func readsTimesOfDay() {
        #expect(moment("15:00") == .clock(hour: 15, minute: 0))
        #expect(moment("9:05") == .clock(hour: 9, minute: 5))
        #expect(moment("24:00") == .clock(hour: 24, minute: 0))
    }

    @Test func rejectsWhatIsntATime() {
        for text in ["", "15", "15:0", "25:00", "24:30", "12:60", "15:00Z", "tomorrow", "2026-13-01", "2026-11-32",
                     "2026-11-16X15:00", "2026-11-16T15:00junk", "2026-11-16T15:00+1"] {
            #expect(TimelineContent.Moment.parse(text) == nil, "\(text)")
        }
    }

    @Test func numbersAreHoursOrUnixTime() {
        #expect(TimelineContent.Moment(number: 9) == .clock(hour: 9, minute: 0))
        #expect(TimelineContent.Moment(number: 9.5) == .clock(hour: 9, minute: 30))
        #expect(TimelineContent.Moment(number: 24) == .clock(hour: 24, minute: 0))
        let instant = TimelineContent.Moment.instant(Date(timeIntervalSince1970: midnightUTC))
        #expect(TimelineContent.Moment(number: midnightUTC) == instant)
        #expect(TimelineContent.Moment(number: midnightUTC * 1000) == instant)
        #expect(TimelineContent.Moment(number: -1) == nil)
    }

    @Test func numbersInTheOutput() throws {
        let content = try timeline(#"{ "timeline": { "from": 8, "to": 18.5, "events": [{ "title": "a", "start": 1794787200 }] } }"#)
        #expect(content.from == .clock(hour: 8, minute: 0))
        #expect(content.to == .clock(hour: 18, minute: 30))
        #expect(content.events[0].start == .instant(Date(timeIntervalSince1970: midnightUTC)))
    }

    @Test func localTimesUseTheGivenZone() {
        let local = moment("2026-11-16T15:00")
        #expect(local.date(now: .now, calendar: calendar) == Date(timeIntervalSince1970: midnightUTC + 14 * 3600))
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        #expect(local.date(now: .now, calendar: tokyo) == Date(timeIntervalSince1970: midnightUTC + 6 * 3600))
        // An instant is the same anywhere.
        let instant = moment("2026-11-16T15:00Z")
        #expect(instant.date(now: .now, calendar: tokyo) == instant.date(now: .now, calendar: calendar))
    }

    @Test func timesOfDayAreOnNowsDay() {
        let lateEvening = at("2026-11-16T23:30")
        #expect(moment("15:00").date(now: lateEvening, calendar: calendar) == at("2026-11-16T15:00"))
        #expect(moment("24:00").date(now: lateEvening, calendar: calendar) == at("2026-11-17T00:00"))
        #expect(moment("00:00").date(now: at("2026-11-17T00:10"), calendar: calendar) == at("2026-11-17T00:00"))
    }

    // MARK: Now and next

    @Test func statesCurrentAndNext() {
        let snapshot = day.snapshot(now: at("2026-11-16T13:40"), calendar: calendar)
        #expect(snapshot.items.map(\.state) == [.past, .past, .past, .now, .upcoming, .upcoming])
        #expect(snapshot.current?.event.title == "Focus time")
        #expect(snapshot.next?.event.title == "Sprint review")
        #expect(abs(snapshot.progress(of: snapshot.current!) - 40.0 / 90) < 1e-9)
    }

    @Test func ofOverlappingEventsTheLatestStartedIsCurrent() {
        let content = TimelineContent(events: [
            .init(title: "Workday", start: moment("2026-11-16T08:00"), end: moment("2026-11-16T17:00")),
            .init(title: "Meeting", start: moment("2026-11-16T13:00"), end: moment("2026-11-16T14:00")),
        ])
        #expect(content.snapshot(now: at("2026-11-16T13:30"), calendar: calendar).current?.event.title == "Meeting")
        #expect(content.snapshot(now: at("2026-11-16T14:30"), calendar: calendar).current?.event.title == "Workday")
    }

    @Test func eventsAreSortedByStartAndKeepTheirIndex() {
        let content = TimelineContent(events: [
            .init(title: "b", start: moment("11:00")),
            .init(title: "a", start: moment("10:00")),
        ])
        let snapshot = content.snapshot(now: at("2026-11-16T09:00"), calendar: calendar)
        #expect(snapshot.items.map(\.event.title) == ["a", "b"])
        #expect(snapshot.items.map(\.index) == [1, 0])
    }

    @Test func anEndBeforeTheStartIsAMoment() {
        let content = TimelineContent(events: [.init(title: "a", start: moment("2026-11-16T15:00"), end: moment("2026-11-16T14:00"))])
        let item = content.snapshot(now: at("2026-11-16T09:00"), calendar: calendar).items[0]
        #expect(item.end == item.start)
        #expect(item.isPoint)
        #expect(item.time == "15:00")
    }

    @Test func timesOfDayRunPastMidnight() {
        let content = TimelineContent(events: [.init(title: "Night shift", start: moment("23:00"), end: moment("01:00"))])
        let item = content.snapshot(now: at("2026-11-16T22:00"), calendar: calendar).items[0]
        #expect(item.end == at("2026-11-17T01:00"))
        #expect(item.time == "23:00–Tue 01:00")
    }

    // MARK: Countdown

    @Test func durations() {
        #expect(TimelineText.duration(0) == "0m")
        #expect(TimelineText.duration(1) == "1m")
        #expect(TimelineText.duration(59) == "1m")
        #expect(TimelineText.duration(720) == "12m")
        #expect(TimelineText.duration(690) == "12m")
        #expect(TimelineText.duration(3600) == "1h")
        #expect(TimelineText.duration(7500) == "2h 5m")
        #expect(TimelineText.duration(86400) == "1d")
        #expect(TimelineText.duration(100_800) == "1d 4h")
        #expect(TimelineText.countdown(720) == "in 12m")
        #expect(TimelineText.countdown(0) == "now")
        #expect(TimelineText.countdown(-30) == "now")
    }

    @Test func countdownToTheNextEvent() {
        let countdown = day.snapshot(now: at("2026-11-16T08:00"), calendar: calendar).countdown
        #expect(countdown == .init(label: "in", value: "1h 15m", title: "Standup", detail: "09:15–09:30", tone: .info, progress: nil))
    }

    @Test func countdownToTheEndOfTheCurrentEvent() {
        let countdown = day.snapshot(now: at("2026-11-16T13:40"), calendar: calendar).countdown
        #expect(countdown.label == "ends in")
        #expect(countdown.value == "50m")
        #expect(countdown.title == "Focus time")
        #expect(countdown.detail == "13:00–14:30 · no meetings")
        #expect(countdown.tone == .success)
        #expect(abs((countdown.progress ?? 0) - 40.0 / 90) < 1e-9)
    }

    @Test func countdownSaysNowAsAnEventStarts() {
        let countdown = day.snapshot(now: at("2026-11-16T15:00:30"), calendar: calendar).countdown
        #expect(countdown.label == nil)
        #expect(countdown.value == "now")
        #expect(countdown.title == "Sprint review")
    }

    @Test func countdownCountsDownBetweenRuns() {
        let content = day
        let values = ["14:38", "14:45", "14:59:30"].map {
            content.snapshot(now: at("2026-11-16T" + $0), calendar: calendar).countdown.value
        }
        // 14:30 ended Focus time, so these count to Sprint review.
        #expect(values == ["22m", "15m", "1m"])
    }

    @Test func countdownWithNothingLeft() {
        let countdown = day.snapshot(now: at("2026-11-16T18:00"), calendar: calendar).countdown
        #expect(countdown.value == nil)
        #expect(countdown.title == "Nothing coming up")
        #expect(countdown.tone == .muted)
    }

    // MARK: Notes

    @Test func notesForNowNextAndWhatsLeft() {
        let notes = day.snapshot(now: at("2026-11-16T13:40"), calendar: calendar).notes
        #expect(notes == [
            .init(key: "Now", title: "Focus time", detail: "until 14:30"),
            .init(key: "Next", title: "Sprint review", detail: "15:00, in 1h 20m"),
            .init(key: "Left", title: "2h 20m", detail: "in 3 events"),
        ])
    }

    @Test func notesCountOverlapsOnceAndStopAtTheWindow() {
        let content = TimelineContent(to: moment("17:00"), events: [
            .init(title: "a", start: moment("2026-11-16T10:00"), end: moment("2026-11-16T12:00")),
            .init(title: "b", start: moment("2026-11-16T11:00"), end: moment("2026-11-16T13:00")),
            .init(title: "c", start: moment("2026-11-16T16:00"), end: moment("2026-11-16T18:00")),
        ])
        let notes = content.snapshot(now: at("2026-11-16T09:00"), calendar: calendar).notes
        #expect(notes.last == .init(key: "Left", title: "4h", detail: "in 3 events"))
    }

    @Test func notesOnOtherDaysNameTheDay() {
        let content = TimelineContent(events: [.init(title: "Prod window", start: moment("2026-11-19T14:00"), end: moment("2026-11-19T15:00"))])
        let notes = content.snapshot(now: at("2026-11-18T09:30"), calendar: calendar).notes
        #expect(notes == [.init(key: "Next", title: "Prod window", detail: "Thu 14:00, in 1d 4h")])
    }

    @Test func clockTexts() {
        let now = at("2026-11-16T13:40")
        #expect(TimelineText.clock(at("2026-11-16T09:05"), now: now, calendar: calendar) == "09:05")
        #expect(TimelineText.clock(at("2026-11-19T14:00"), now: now, calendar: calendar) == "Thu 14:00")
        #expect(TimelineText.clock(at("2026-11-17T00:00"), now: now, calendar: calendar) == "Tue")
        #expect(TimelineText.clock(at("2026-12-14T00:00"), now: now, calendar: calendar) == "Dec 14")
        #expect(TimelineText.clock(at("2026-12-14T09:30"), now: now, calendar: calendar) == "Dec 14 09:30")
    }

    @Test func eventTimes() {
        let content = TimelineContent(events: [
            .init(title: "a", start: moment("2026-11-16T10:00"), end: moment("2026-11-16T11:00"), subtitle: "Room Kajen"),
            .init(title: "b", start: moment("2026-11-16T16:15")),
            .init(title: "c", start: moment("2026-11-16T22:00"), end: moment("2026-11-17T00:00")),
            .init(title: "d", start: moment("2026-11-18T09:00"), end: moment("2026-11-18T10:00")),
        ])
        let items = content.snapshot(now: at("2026-11-16T09:00"), calendar: calendar).items
        #expect(items.map(\.time) == ["10:00–11:00", "16:15", "22:00–24:00", "Wed 09:00–10:00"])
        #expect(items.map(\.startTime) == ["10:00", "16:15", "22:00", "Wed 09:00"])
        #expect(items[0].detail == "10:00–11:00 · Room Kajen")
    }

    // MARK: Window and positions

    @Test func positionsInTheWindow() {
        let snapshot = day.snapshot(now: at("2026-11-16T13:40"), calendar: calendar)
        #expect(snapshot.window == DateInterval(start: at("2026-11-16T09:00"), end: at("2026-11-16T17:00")))
        #expect(abs((snapshot.nowPosition ?? 0) - 280.0 / 480) < 1e-9)
        let focus = snapshot.items[3]
        #expect(focus.from == 0.5)
        #expect(focus.to == 0.6875)
        #expect(snapshot.position(of: at("2026-11-16T07:00")) == -0.25)
    }

    @Test func nowOutsideTheWindowIsNotDrawn() {
        #expect(day.snapshot(now: at("2026-11-16T18:00"), calendar: calendar).nowPosition == nil)
        #expect(day.snapshot(now: at("2026-11-16T08:59"), calendar: calendar).nowPosition == nil)
        #expect(day.snapshot(now: at("2026-11-16T17:00"), calendar: calendar).nowPosition == 1)
    }

    @Test func eventsAreCutToTheWindow() {
        let content = TimelineContent(from: moment("09:00"), to: moment("17:00"), events: [
            .init(title: "early", start: moment("2026-11-16T08:00"), end: moment("2026-11-16T10:00")),
            .init(title: "before", start: moment("2026-11-16T07:00"), end: moment("2026-11-16T08:00")),
            .init(title: "late", start: moment("2026-11-16T16:00"), end: moment("2026-11-16T19:00")),
            .init(title: "tomorrow", start: moment("2026-11-17T10:00")),
            .init(title: "at the end", start: moment("2026-11-16T17:00")),
        ])
        let items = content.snapshot(now: at("2026-11-16T12:00"), calendar: calendar).items
        let byTitle = Dictionary(uniqueKeysWithValues: items.map { ($0.event.title, $0) })
        #expect(byTitle["early"]?.from == 0)
        #expect(byTitle["early"]?.to == 0.125)
        #expect(byTitle["early"]?.isInWindow == true)
        #expect(byTitle["before"]?.isInWindow == false)
        #expect(byTitle["late"]?.to == 1)
        #expect(byTitle["tomorrow"]?.isInWindow == false)
        #expect(byTitle["at the end"]?.isInWindow == true)
    }

    @Test func withoutFromAndToTheWindowIsTheEventsWholeHours() {
        var content = day
        content.from = nil
        content.to = nil
        let window = content.snapshot(now: at("2026-11-16T13:40"), calendar: calendar).window
        #expect(window == DateInterval(start: at("2026-11-16T09:00"), end: at("2026-11-16T17:00")))
    }

    @Test func withoutEventsTheWindowStartsThisHour() {
        let window = TimelineContent(events: []).snapshot(now: at("2026-11-16T13:40"), calendar: calendar).window
        #expect(window == DateInterval(start: at("2026-11-16T13:00"), end: at("2026-11-16T21:00")))
    }

    @Test func aWindowCanRunPastMidnight() {
        let window = TimelineContent(from: moment("22:00"), to: moment("02:00"), events: [])
            .snapshot(now: at("2026-11-16T23:00"), calendar: calendar).window
        #expect(window == DateInterval(start: at("2026-11-16T22:00"), end: at("2026-11-17T02:00")))
    }

    @Test func aWindowIsAtLeastAnHour() {
        let content = TimelineContent(events: [.init(title: "a", start: moment("2026-11-16T15:00"))])
        let window = content.snapshot(now: at("2026-11-16T13:00"), calendar: calendar).window
        #expect(window == DateInterval(start: at("2026-11-16T15:00"), end: at("2026-11-16T16:00")))
    }

    @Test func overlappingEventsShareColumns() {
        let lanes = TimelineContent.Snapshot.lanes([
            (at("2026-11-16T10:00"), at("2026-11-16T11:00")),
            (at("2026-11-16T10:30"), at("2026-11-16T11:30")),
            (at("2026-11-16T11:00"), at("2026-11-16T12:00")),
            (at("2026-11-16T13:00"), at("2026-11-16T14:00")),
            // A moment takes 15 minutes, so the next one starting at it gets its own column.
            (at("2026-11-16T15:00"), at("2026-11-16T15:00")),
            (at("2026-11-16T15:00"), at("2026-11-16T15:30")),
        ])
        #expect(lanes.map { $0.lane } == [0, 1, 0, 0, 0, 1])
        #expect(lanes.map { $0.lanes } == [2, 2, 2, 1, 2, 2])
    }

    // MARK: Ticks

    @Test func hourTicks() {
        let snapshot = day.snapshot(now: at("2026-11-16T13:40"), calendar: calendar)
        #expect(snapshot.ticks(max: 9).map(\.label) == ["09", "10", "11", "12", "13", "14", "15", "16", "17"])
        let fewer = snapshot.ticks(max: 5)
        #expect(fewer.map(\.label) == ["10", "12", "14", "16"])
        #expect(fewer.map(\.position) == [0.125, 0.375, 0.625, 0.875])
    }

    @Test func ticksIncludeBothEndsWhenTheyFall() {
        let content = TimelineContent(from: moment("08:00"), to: moment("18:00"), events: [])
        let ticks = content.snapshot(now: at("2026-11-16T13:40"), calendar: calendar).ticks(max: 6)
        #expect(ticks.map(\.label) == ["08", "10", "12", "14", "16", "18"])
        #expect(ticks.first?.position == 0)
        #expect(ticks.last?.position == 1)
    }

    @Test func shortWindowsTickInMinutes() {
        let content = TimelineContent(from: moment("09:00"), to: moment("10:00"), events: [])
        let ticks = content.snapshot(now: at("2026-11-16T09:10"), calendar: calendar).ticks(max: 4)
        #expect(ticks.map(\.label) == ["09:00", "09:30", "10:00"])
    }

    @Test func aWeekTicksByDayName() {
        let content = TimelineContent(from: moment("2026-11-16"), to: moment("2026-11-21"), events: [])
        let ticks = content.snapshot(now: at("2026-11-18T13:00"), calendar: calendar).ticks(max: 6)
        #expect(ticks.map(\.label) == ["Mon", "Tue", "Wed", "Thu", "Fri"])
        #expect(ticks.first?.position == 0.1)
    }

    @Test func monthsTickByDate() {
        let content = TimelineContent(from: moment("2026-10-05"), to: moment("2026-12-14"), events: [])
        let ticks = content.snapshot(now: at("2026-11-18T13:00"), calendar: calendar).ticks(max: 4)
        #expect(ticks.map(\.label) == ["Oct 5", "Nov 2", "Nov 30"])
    }
}
