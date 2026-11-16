import Foundation

/// What's now, what's next and how long until:
/// `{ "timeline": { "events": [{ "title": "Standup", "start": "2026-11-16T09:15" }] } }`.
/// Tjuvkik draws now and counts down itself, so the tile stays right between runs. An s tile
/// shows a countdown, m the day as a strip, l an agenda with hour lines.
public struct TimelineContent: Equatable, Sendable, Decodable {
    public struct Event: Equatable, Sendable, Decodable {
        public var title: String
        public var start: Moment
        /// Nil for a moment rather than a span.
        public var end: Moment?
        /// After the time, like a room or "Teams".
        public var subtitle: String?
        public var tone: Tone?
        /// Kept for opening from the menu later; not used yet.
        public var url: String?
        /// Kept for running from the menu later; not used yet.
        public var command: String?

        public init(title: String, start: Moment, end: Moment? = nil, subtitle: String? = nil, tone: Tone? = nil,
                    url: String? = nil, command: String? = nil) {
            self.title = title
            self.start = start
            self.end = end
            self.subtitle = subtitle
            self.tone = tone
            self.url = url
            self.command = command
        }

        private enum CodingKeys: String, CodingKey { case title, start, end, subtitle, tone, url, command }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decodeText(forKey: .title)
            start = try container.decode(Moment.self, forKey: .start)
            end = try container.decodeIfPresent(Moment.self, forKey: .end)
            subtitle = try container.decodeTextIfPresent(forKey: .subtitle)
            tone = try container.decodeIfPresent(Tone.self, forKey: .tone)
            url = try container.decodeIfPresent(String.self, forKey: .url)
            command = try container.decodeIfPresent(String.self, forKey: .command)
        }
    }

    /// A time as the script wrote it. Local times are placed in the viewer's time zone when drawn.
    public enum Moment: Equatable, Sendable, Decodable {
        /// A fixed instant: written with a zone (`Z`, `+01:00`) or as Unix seconds.
        case instant(Date)
        /// A local date and time: `2026-11-16T15:00`, or `2026-11-16` for midnight.
        case local(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int)
        /// A time of day, today: `15:00`. `24:00` is the end of today.
        case clock(hour: Int, minute: Int)

        /// Reads `2026-11-16T15:00`, with or without seconds and a zone, `2026-11-16`, or `15:00`.
        public static func parse(_ text: String) -> Moment? {
            var reader = Reader(text.trimmingCharacters(in: .whitespaces))
            var date: (year: Int, month: Int, day: Int)?
            var probe = reader
            if let year = probe.number(digits: 4...4), probe.skip("-") {
                guard let month = probe.number(digits: 1...2), probe.skip("-"), let day = probe.number(digits: 1...2),
                      (1...12).contains(month), (1...31).contains(day) else { return nil }
                if probe.isAtEnd { return .local(year: year, month: month, day: day, hour: 0, minute: 0, second: 0) }
                guard probe.skip(oneOf: ["T", "t", " "]) != nil else { return nil }
                date = (year, month, day)
                reader = probe
            }
            guard let hour = reader.number(digits: 1...2), reader.skip(":"), let minute = reader.number(digits: 2...2) else { return nil }
            var second = 0
            if reader.skip(":") {
                guard let value = reader.number(digits: 2...2) else { return nil }
                second = value
                if reader.skip(".") || reader.skip(",") {
                    guard reader.skipDigits() > 0 else { return nil }
                }
            }
            guard hour <= 24, minute <= 59, second <= 60, hour < 24 || (minute == 0 && second == 0) else { return nil }
            _ = reader.skip(" ")
            var offset: Int?
            if reader.skip("Z") || reader.skip("z") {
                offset = 0
            } else if let sign = reader.skip(oneOf: ["+", "-", "−"]) {
                guard let hours = reader.number(digits: 2...2) else { return nil }
                _ = reader.skip(":")
                let minutes = reader.number(digits: 2...2) ?? 0
                guard hours <= 18, minutes <= 59 else { return nil }
                offset = (sign == "+" ? 1 : -1) * (hours * 3600 + minutes * 60)
            }
            guard reader.isAtEnd else { return nil }
            guard let date else {
                // A time of day with a zone would need a day to place it on.
                return offset == nil ? .clock(hour: hour, minute: minute) : nil
            }
            guard let offset else {
                return .local(year: date.year, month: date.month, day: date.day, hour: hour, minute: minute, second: second)
            }
            var calendar = Calendar(identifier: .gregorian)
            guard let zone = TimeZone(secondsFromGMT: offset) else { return nil }
            calendar.timeZone = zone
            return Moment.date(year: date.year, month: date.month, day: date.day, hour: hour, minute: minute, second: second, in: calendar)
                .map(Moment.instant)
        }

        /// Up to 24 is hours today (`9.5` is 09:30); more is Unix seconds, or milliseconds when huge.
        public init?(number: Double) {
            guard number.isFinite, number >= 0 else { return nil }
            if number <= 24 {
                let minutes = Int((number * 60).rounded())
                self = .clock(hour: minutes / 60, minute: minutes % 60)
            } else {
                self = .instant(Date(timeIntervalSince1970: number > 100_000_000_000 ? number / 1000 : number))
            }
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let number = try? container.decode(Double.self), let moment = Moment(number: number) {
                self = moment
                return
            }
            if let text = try? container.decode(String.self), let moment = Moment.parse(text) {
                self = moment
                return
            }
            throw DecodingError.typeMismatch(Moment.self, .init(codingPath: decoder.codingPath,
                                                                debugDescription: "Expected a time like 2026-11-16T15:00 or 15:00"))
        }

        /// The instant, with local times in `calendar`'s time zone and times of day on `now`'s day.
        public func date(now: Date, calendar: Calendar) -> Date? {
            switch self {
            case .instant(let date):
                return date
            case let .local(year, month, day, hour, minute, second):
                return Moment.date(year: year, month: month, day: day, hour: hour, minute: minute, second: second, in: calendar)
            case let .clock(hour, minute):
                let today = calendar.dateComponents([.year, .month, .day], from: now)
                guard let year = today.year, let month = today.month, let day = today.day else { return nil }
                return Moment.date(year: year, month: month, day: day, hour: hour, minute: minute, second: 0, in: calendar)
            }
        }

        var isClock: Bool {
            if case .clock = self { return true }
            return false
        }

        private static func date(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, in calendar: Calendar) -> Date? {
            if hour >= 24 {
                return calendar.date(from: DateComponents(year: year, month: month, day: day))
                    .flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }
            }
            return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))
        }
    }

    /// Where the visible window starts and ends. Without them, the events' first and last hour.
    public var from: Moment?
    public var to: Moment?
    public var events: [Event]
    public var extras: PanelExtras

    public init(from: Moment? = nil, to: Moment? = nil, events: [Event], extras: PanelExtras = PanelExtras()) {
        self.from = from
        self.to = to
        self.events = events
        self.extras = extras
    }

    private enum CodingKeys: String, CodingKey { case timeline }
    private enum TimelineKeys: String, CodingKey { case from, to, events }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let timeline = try? container.nestedContainer(keyedBy: TimelineKeys.self, forKey: .timeline) {
            from = try timeline.decodeIfPresent(Moment.self, forKey: .from)
            to = try timeline.decodeIfPresent(Moment.self, forKey: .to)
            events = try timeline.decode([Event].self, forKey: .events)
        } else {
            // `"timeline": [...]`: just the events.
            from = nil
            to = nil
            events = try container.decode([Event].self, forKey: .timeline)
        }
        extras = try PanelExtras(from: decoder)
    }

    /// The timeline at `now`, with local times in `calendar`'s time zone.
    public func snapshot(now: Date, calendar: Calendar) -> Snapshot {
        Snapshot(content: self, now: now, calendar: calendar)
    }
}

extension TimelineContent {
    /// The timeline at one moment: where each event sits in the window, what's now and next, and
    /// the texts the tile shows. Everything that depends on the clock is here, so the view only draws.
    public struct Snapshot: Equatable, Sendable {
        public enum State: Equatable, Sendable { case past, now, upcoming }

        public struct Item: Equatable, Sendable {
            /// Its index in `events`.
            public var index: Int
            public var event: Event
            public var start: Date
            public var end: Date
            public var state: State
            /// Where it starts and ends in the window, 0 to 1, cut to the window.
            public var from: Double
            public var to: Double
            /// Whether any of it is in the window.
            public var isInWindow: Bool
            /// Its column among the events it overlaps, and how many columns they need.
            public var lane: Int
            public var lanes: Int
            /// "10:00–11:00", or "Thu 14:00" for a moment.
            public var time: String
            /// "10:00".
            public var startTime: String

            public var isPoint: Bool { start == end }
            /// The time, then the subtitle: "15:00–16:00 · Teams".
            public var detail: String {
                [time, event.subtitle].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
            }
        }

        /// A label on the axis, or an hour line.
        public struct Tick: Equatable, Sendable {
            /// 0 to 1 through the window.
            public var position: Double
            public var label: String
        }

        /// A line under the strip: "NOW Focus time until 14:30".
        public struct Note: Equatable, Sendable {
            public var key: String
            public var title: String
            public var detail: String?
        }

        /// What an s tile shows.
        public struct Countdown: Equatable, Sendable {
            /// Above the value: "in", "ends in".
            public var label: String?
            /// The big text: "1h 20m", "now".
            public var value: String?
            public var title: String
            public var detail: String?
            public var tone: Tone?
            /// How far through the current event, 0 to 1.
            public var progress: Double?
        }

        public var now: Date
        public var calendar: Calendar
        public var window: DateInterval
        /// Every event, by start.
        public var items: [Item]

        public init(content: TimelineContent, now: Date, calendar: Calendar) {
            self.now = now
            self.calendar = calendar
            var resolved: [Resolved] = []
            for (index, event) in content.events.enumerated() {
                guard let start = event.start.date(now: now, calendar: calendar) else { continue }
                var end = event.end?.date(now: now, calendar: calendar) ?? start
                // "23:00" to "01:00" ends tomorrow.
                if end < start, event.start.isClock, event.end?.isClock == true {
                    end = calendar.date(byAdding: .day, value: 1, to: end) ?? start
                }
                resolved.append(Resolved(index: index, event: event, start: start, end: max(end, start)))
            }
            resolved.sort { ($0.start, $0.index) < ($1.start, $1.index) }

            let spans = resolved.map { ($0.start, $0.end) }
            let window = Snapshot.makeWindow(content: content, spans: spans, now: now, calendar: calendar)
            self.window = window
            let lanes = Snapshot.lanes(spans)
            var items: [Item] = []
            for (offset, entry) in resolved.enumerated() {
                let state: State = entry.end <= now ? .past : entry.start <= now ? .now : .upcoming
                let isPoint = entry.start == entry.end
                let inWindow = isPoint
                    ? window.start <= entry.start && entry.start <= window.end
                    : entry.end > window.start && entry.start < window.end
                let startTime = TimelineText.clock(entry.start, now: now, calendar: calendar)
                let time = isPoint ? startTime : startTime + "–" + TimelineText.end(entry.end, start: entry.start, calendar: calendar)
                items.append(Item(index: entry.index, event: entry.event, start: entry.start, end: entry.end, state: state,
                                  from: Snapshot.clamp(Snapshot.position(entry.start, in: window)),
                                  to: Snapshot.clamp(Snapshot.position(entry.end, in: window)),
                                  isInWindow: inWindow, lane: lanes[offset].lane, lanes: lanes[offset].lanes,
                                  time: time, startTime: startTime))
            }
            self.items = items
        }

        private struct Resolved {
            var index: Int
            var event: Event
            var start: Date
            var end: Date
        }

        /// The event going on now; of several, the one that started last.
        public var current: Item? {
            items.last(where: { $0.state == .now })
        }

        /// The first event that hasn't started.
        public var next: Item? {
            items.first(where: { $0.state == .upcoming })
        }

        /// Where now is in the window, 0 to 1, or nil outside it.
        public var nowPosition: Double? {
            let position = Snapshot.position(now, in: window)
            return (0...1).contains(position) ? position : nil
        }

        /// Where `date` is in the window: 0 at its start, 1 at its end, beyond for outside.
        public func position(of date: Date) -> Double {
            Snapshot.position(date, in: window)
        }

        /// How far through `item` now is, 0 to 1.
        public func progress(of item: Item) -> Double {
            guard item.end > item.start else { return now >= item.start ? 1 : 0 }
            return Snapshot.clamp(now.timeIntervalSince(item.start) / item.end.timeIntervalSince(item.start))
        }

        public var countdown: Countdown {
            if let current {
                let justStarted = now.timeIntervalSince(current.start) < 60
                return Countdown(label: justStarted ? nil : "ends in",
                                 value: justStarted ? "now" : TimelineText.duration(current.end.timeIntervalSince(now)),
                                 title: current.event.title, detail: current.detail, tone: current.event.tone,
                                 progress: progress(of: current))
            }
            if let next {
                return Countdown(label: "in", value: TimelineText.duration(next.start.timeIntervalSince(now)),
                                 title: next.event.title, detail: next.detail, tone: next.event.tone, progress: nil)
            }
            return Countdown(label: nil, value: nil, title: "Nothing coming up", detail: nil, tone: .muted, progress: nil)
        }

        /// Now, next, and how much is left in the window when more than one event is.
        public var notes: [Note] {
            var notes: [Note] = []
            if let current {
                notes.append(Note(key: "Now", title: current.event.title,
                                  detail: "until " + TimelineText.clock(current.end, now: now, calendar: calendar)))
            }
            if let next {
                notes.append(Note(key: "Next", title: next.event.title,
                                  detail: TimelineText.clock(next.start, now: now, calendar: calendar) + ", "
                                      + TimelineText.countdown(next.start.timeIntervalSince(now))))
            }
            let left = items
                .filter { $0.state != .past }
                .map { (max($0.start, now), min($0.end, window.end)) }
                .filter { $0.0 < $0.1 }
            if left.count > 1 {
                let seconds = Snapshot.covered(left)
                notes.append(Note(key: "Left", title: TimelineText.duration(seconds), detail: "in \(left.count) events"))
            }
            return notes
        }

        /// Labels for the window, at most `count` of them, on whole hours or days.
        public func ticks(max count: Int) -> [Tick] {
            let span = window.duration
            guard span > 0 else { return [] }
            let hour: TimeInterval = 3600, day: TimeInterval = 86400
            let steps: [TimeInterval] = (span < 3 * hour ? [900, 1800] : [])
                + [hour, 2 * hour, 3 * hour, 4 * hour, 6 * hour, 12 * hour, day, 2 * day, 7 * day, 14 * day, 28 * day, 91 * day]
            let limit = Double(Swift.max(count, 2))
            let step = steps.first { (span / $0).rounded(.down) + 1 <= limit } ?? steps[steps.count - 1]
            let first = calendar.startOfDay(for: window.start)
            var ticks: [Tick] = []
            for k in 0..<1000 {
                let date: Date?
                if step < day {
                    date = calendar.date(byAdding: .minute, value: k * Int(step / 60), to: first)
                } else {
                    let start = calendar.date(byAdding: .day, value: k * Int(step / day), to: first)
                    // A day's name sits in its middle.
                    date = step == day ? start.flatMap { calendar.date(byAdding: .hour, value: 12, to: $0) } : start
                }
                guard let date, date <= window.end.addingTimeInterval(1) else { break }
                let position = Snapshot.position(date, in: window)
                guard position >= -0.0001 else { continue }
                ticks.append(Tick(position: Snapshot.clamp(position), label: tickLabel(date, step: step, span: span)))
            }
            return ticks
        }

        private func tickLabel(_ date: Date, step: TimeInterval, span: TimeInterval) -> String {
            let parts = calendar.dateComponents([.hour, .minute, .weekday, .month, .day], from: date)
            if step < 86400 {
                let hour = TimelineText.twoDigits(parts.hour ?? 0)
                return step < 3600 ? hour + ":" + TimelineText.twoDigits(parts.minute ?? 0) : hour
            }
            if step == 86400 && span <= 8 * 86400 { return TimelineText.weekday(parts.weekday ?? 1) }
            return TimelineText.month(parts.month ?? 1) + " \(parts.day ?? 1)"
        }

        // MARK: Layout

        private static func position(_ date: Date, in window: DateInterval) -> Double {
            window.duration > 0 ? date.timeIntervalSince(window.start) / window.duration : 0
        }

        private static func clamp(_ value: Double) -> Double {
            min(max(value, 0), 1)
        }

        private static func makeWindow(content: TimelineContent, spans: [(Date, Date)], now: Date, calendar: Calendar) -> DateInterval {
            let floorHour = { (date: Date) in calendar.dateInterval(of: .hour, for: date)?.start ?? date }
            let ceilHour = { (date: Date) -> Date in
                let floor = floorHour(date)
                return floor == date ? date : calendar.date(byAdding: .hour, value: 1, to: floor) ?? date
            }
            let start = content.from?.date(now: now, calendar: calendar)
                ?? spans.map { $0.0 }.min().map(floorHour)
                ?? floorHour(now)
            var end = content.to?.date(now: now, calendar: calendar)
                ?? spans.map { $0.1 }.max().map(ceilHour)
                ?? calendar.date(byAdding: .hour, value: 8, to: start)
                ?? start.addingTimeInterval(8 * 3600)
            // "22:00" to "02:00" runs past midnight.
            if end <= start, content.to?.isClock == true, let tomorrow = calendar.date(byAdding: .day, value: 1, to: end) {
                end = tomorrow
            }
            if end <= start {
                end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
            }
            return DateInterval(start: start, end: max(end, start.addingTimeInterval(60)))
        }

        /// Columns for overlapping events, in start order: each takes the first free column, and
        /// every event in a run of overlapping ones gets the run's column count. Moments take
        /// 15 minutes, since they're drawn with a height.
        static func lanes(_ spans: [(Date, Date)]) -> [(lane: Int, lanes: Int)] {
            var result = Array(repeating: (lane: 0, lanes: 1), count: spans.count)
            var laneEnds: [Date] = []
            var runStart = 0
            var runEnd = Date.distantPast
            func closeRun(before index: Int) {
                for j in runStart..<index { result[j].lanes = max(laneEnds.count, 1) }
            }
            for (index, span) in spans.enumerated() {
                let start = span.0
                let end = max(span.1, span.0.addingTimeInterval(15 * 60))
                if index > 0 && start >= runEnd {
                    closeRun(before: index)
                    runStart = index
                    laneEnds = []
                    runEnd = .distantPast
                }
                if let free = laneEnds.firstIndex(where: { $0 <= start }) {
                    result[index].lane = free
                    laneEnds[free] = end
                } else {
                    result[index].lane = laneEnds.count
                    laneEnds.append(end)
                }
                runEnd = max(runEnd, end)
            }
            closeRun(before: spans.count)
            return result
        }

        /// Seconds covered by any of `spans`, counting overlaps once.
        static func covered(_ spans: [(Date, Date)]) -> TimeInterval {
            var total: TimeInterval = 0
            var reach = Date.distantPast
            for (start, end) in spans.sorted(by: { $0.0 < $1.0 }) where end > reach {
                total += end.timeIntervalSince(max(start, reach))
                reach = end
            }
            return total
        }
    }
}

/// How the timeline writes times and durations.
public enum TimelineText {
    /// `12m`, `2h 5m`, `2h`, `1d 4h`. Rounds up to the minute, so it reaches 0 when the time comes.
    public static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(Int(((seconds - 0.001) / 60).rounded(.up)), 0)
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return minutes % 60 == 0 ? "\(hours)h" : "\(hours)h \(minutes % 60)m" }
        return hours % 24 == 0 ? "\(hours / 24)d" : "\(hours / 24)d \(hours % 24)h"
    }

    /// `in 12m`, or `now` once it's time.
    public static func countdown(_ seconds: TimeInterval) -> String {
        seconds <= 0 ? "now" : "in " + duration(seconds)
    }

    /// `14:30` today, `Thu 14:30` within a week, `Dec 14 14:30` further off. Midnight drops the time.
    public static func clock(_ date: Date, now: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute, .weekday, .month, .day], from: date)
        let time = twoDigits(parts.hour ?? 0) + ":" + twoDigits(parts.minute ?? 0)
        if calendar.isDate(date, inSameDayAs: now) { return time }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 99
        let day = abs(days) < 7 ? weekday(parts.weekday ?? 1) : month(parts.month ?? 1) + " \(parts.day ?? 1)"
        return parts.hour == 0 && parts.minute == 0 ? day : day + " " + time
    }

    /// An event's end after its start: `16:00` on the same day, `24:00` at the midnight after it,
    /// else as `clock` counts from the start: `Tue 02:00`.
    static func end(_ end: Date, start: Date, calendar: Calendar) -> String {
        if !calendar.isDate(end, inSameDayAs: start), end == calendar.startOfDay(for: end),
           calendar.isDate(end.addingTimeInterval(-1), inSameDayAs: start) {
            return "24:00"
        }
        return clock(end, now: start, calendar: calendar)
    }

    static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    /// 1 is Sunday, as `Calendar` counts.
    static func weekday(_ value: Int) -> String {
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][(value - 1 + 7) % 7]
    }

    static func month(_ value: Int) -> String {
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][(value - 1 + 12) % 12]
    }
}

/// Reads a time, character by character.
private struct Reader {
    private let characters: [Character]
    private var index = 0

    init(_ text: String) { characters = Array(text) }

    var isAtEnd: Bool { index == characters.count }

    mutating func skip(_ character: Character) -> Bool {
        guard !isAtEnd, characters[index] == character else { return false }
        index += 1
        return true
    }

    mutating func skip(oneOf set: Set<Character>) -> Character? {
        guard !isAtEnd, set.contains(characters[index]) else { return nil }
        index += 1
        return characters[index - 1]
    }

    /// A number of `digits` ASCII digits, as many as there are up to the most.
    mutating func number(digits: ClosedRange<Int>) -> Int? {
        var value = 0
        var count = 0
        while index + count < characters.count, count < digits.upperBound,
              characters[index + count].isASCII, let digit = characters[index + count].wholeNumberValue {
            value = value * 10 + digit
            count += 1
        }
        guard count >= digits.lowerBound else { return nil }
        index += count
        return value
    }

    mutating func skipDigits() -> Int {
        var count = 0
        while !isAtEnd, characters[index].isASCII, characters[index].isNumber {
            index += 1
            count += 1
        }
        return count
    }
}
