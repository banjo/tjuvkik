import Foundation

/// Who said what, and when: `{ "items": [{ "author": "Sara Lind", "text": "…", "time": "2026-11-16T13:12:00Z" }] }`.
/// A single cell shows the newest message large, a tile one row high the latest few, and a taller
/// one all that fit, grouped by day.
public struct FeedContent: Equatable, Sendable, Decodable {
    public struct Item: Equatable, Sendable, Decodable {
        /// Who said it. Gives the initials and color when there's no avatar or icon.
        public var author: String?
        /// An image URL, drawn round in place of the initials.
        public var avatar: String?
        /// An emoji or `sf:` symbol drawn in a square instead of the initials, for bots and services.
        public var icon: String?
        /// Where it was said, like "#dsp-spark" or "logbook #1284". `where` in the JSON.
        public var place: String?
        /// The message. `**bold**` is drawn brighter.
        public var text: String
        /// When it was said, read from ISO 8601 or a Unix timestamp. Shown relative.
        public var time: Date?
        /// A `time` that isn't a date, like "2h", shown as is.
        public var timeText: String?
        public var unread: Bool
        /// Opened when the item is picked.
        public var url: String?
        /// `actionTitle` and `actions`, for the glance's keyboard.
        public var actions = RowActions()

        public init(author: String? = nil, avatar: String? = nil, icon: String? = nil, place: String? = nil, text: String,
                    time: Date? = nil, timeText: String? = nil, unread: Bool = false, url: String? = nil) {
            self.author = author
            self.avatar = avatar
            self.icon = icon
            self.place = place
            self.text = text
            self.time = time
            self.timeText = timeText
            self.unread = unread
            self.url = url
        }

        private enum CodingKeys: String, CodingKey {
            case author, avatar, icon, text, time, unread, url
            case place = "where"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            author = try container.decodeTextIfPresent(forKey: .author)
            avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
            icon = try container.decodeIfPresent(String.self, forKey: .icon)
            place = try container.decodeTextIfPresent(forKey: .place)
            text = try container.decodeText(forKey: .text)
            if let seconds = try? container.decode(Double.self, forKey: .time) {
                time = FeedTime.date(fromTimestamp: seconds)
            } else if let raw = try container.decodeIfPresent(String.self, forKey: .time) {
                time = FeedTime.date(from: raw)
                timeText = time == nil && !raw.isEmpty ? raw : nil
            }
            unread = container.decodeFlag(forKey: .unread)
            url = try container.decodeIfPresent(String.self, forKey: .url)
            actions = try RowActions(from: decoder)
        }

        /// The time to show next to the item: relative, or the script's own text.
        public func when(now: Date, calendar: Calendar) -> String? {
            time.map { FeedTime.relative($0, now: now, calendar: calendar) } ?? timeText
        }
    }

    /// A run of items from the same day, newest first.
    public struct Day: Equatable, Sendable {
        /// "Today", "Yesterday", "Monday" or "12 Nov". Nil for items before the first dated one.
        public var title: String?
        public var items: [Item]

        public init(title: String?, items: [Item]) {
            self.title = title
            self.items = items
        }
    }

    /// In the script's order.
    public var items: [Item]
    public var extras: PanelExtras

    public init(items: [Item], extras: PanelExtras = PanelExtras()) {
        self.items = items
        self.extras = extras
    }

    private enum CodingKeys: String, CodingKey { case items }

    public init(from decoder: any Decoder) throws {
        items = try decoder.container(keyedBy: CodingKeys.self).decodeOneOrMany(Item.self, forKey: .items)
        extras = try PanelExtras(from: decoder)
    }

    /// Newest first when every item has a date; otherwise the script's order, which it knows best.
    public var newestFirst: [Item] {
        guard items.allSatisfy({ $0.time != nil }) else { return items }
        // Sorting the indices too keeps items with the same time in the script's order.
        return items.enumerated()
            .sorted { ($0.element.time ?? .distantPast, $1.offset) > ($1.element.time ?? .distantPast, $0.offset) }
            .map(\.element)
    }

    /// The newest item, which an s tile shows.
    public var newest: Item? { newestFirst.first }

    /// Unread items besides the newest, shown as "+3" under it.
    public var moreUnread: Int {
        newestFirst.dropFirst().filter(\.unread).count
    }

    /// The items, newest first, grouped by day. An item without a date stays in the day above it.
    public func days(now: Date, calendar: Calendar) -> [Day] {
        var days: [Day] = []
        for item in newestFirst {
            let title = item.time.map { FeedTime.dayTitle($0, now: now, calendar: calendar) }
            if let last = days.last, title == nil || title == last.title {
                days[days.count - 1].items.append(item)
            } else {
                days.append(Day(title: title, items: [item]))
            }
        }
        return days
    }
}

/// Reading and showing a feed item's time.
public enum FeedTime {
    private static let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// ISO 8601 with a zone (`2026-11-16T13:12:00Z`, `…+01:00`, fractions allowed), or without one
    /// (`2026-11-16T14:12`, `2026-11-16`) in `timeZone`.
    public static func date(from text: String, timeZone: TimeZone = .current) -> Date? {
        let text = text.trimmingCharacters(in: .whitespaces)
        for options: ISO8601DateFormatter.Options in [[.withInternetDateTime], [.withInternetDateTime, .withFractionalSeconds]] {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            if let date = formatter.date(from: text) { return date }
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    /// Seconds since 1970, or milliseconds when it's too big to be seconds.
    public static func date(fromTimestamp value: Double) -> Date {
        Date(timeIntervalSince1970: value > 100_000_000_000 ? value / 1000 : value)
    }

    /// "now", "5m", "2h", "Sun", "12 Nov", "12 Nov 2025". Times ahead of `now` read as now. Yesterday
    /// is its weekday, since at l it already sits under a "Yesterday" heading.
    public static func relative(_ date: Date, now: Date, calendar: Calendar) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        let days = daysBetween(date, now, calendar: calendar)
        // Late last night reads better as hours than as a weekday.
        if days == 0 || seconds < 6 * 3600 { return "\(Int(seconds / 3600))h" }
        if days < 7 { return String(weekday(date, calendar: calendar).prefix(3)) }
        return short(date, now: now, calendar: calendar)
    }

    /// The heading for a day: "Today", "Yesterday", "Monday" within the week, else "12 Nov".
    public static func dayTitle(_ date: Date, now: Date, calendar: Calendar) -> String {
        let days = daysBetween(date, now, calendar: calendar)
        if days <= 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 7 { return weekday(date, calendar: calendar) }
        return short(date, now: now, calendar: calendar)
    }

    /// Calendar days from `date` to `now`: 0 the same day, 1 the day before.
    private static func daysBetween(_ date: Date, _ now: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
    }

    private static func weekday(_ date: Date, calendar: Calendar) -> String {
        weekdays[(calendar.component(.weekday, from: date) - 1 + 7) % 7]
    }

    /// "12 Nov", with the year when it isn't this year's.
    private static func short(_ date: Date, now: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let text = "\(parts.day ?? 1) \(months[((parts.month ?? 1) - 1 + 12) % 12])"
        return parts.year == calendar.component(.year, from: now) ? text : "\(text) \(parts.year ?? 0)"
    }
}

/// What a feed draws for an author without an avatar: initials on a color from the name.
public enum FeedAuthor {
    /// The tones initials are drawn on, picked by name.
    public static let tones: [Tone] = [.accent, .info, .success, .warning, .error]

    /// "SL" for Sara Lind, "AÖ" for Anton Ödman, "Az" for Azure, "?" for nothing.
    public static func initials(_ name: String) -> String {
        let words = name.split { !$0.isLetter && !$0.isNumber }
        guard let first = words.first, let firstLetter = first.first else {
            return name.trimmingCharacters(in: .whitespaces).first.map { String($0) } ?? "?"
        }
        if words.count > 1, let lastLetter = words.last?.first {
            return firstLetter.uppercased() + lastLetter.uppercased()
        }
        return firstLetter.uppercased() + String(first.dropFirst().prefix(1))
    }

    /// The same index for the same name on every run and machine, ignoring case: FNV-1a, not
    /// `hashValue`, which is seeded per process.
    public static func colorIndex(_ name: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt32 = 0x811C_9DC5
        for byte in name.trimmingCharacters(in: .whitespaces).lowercased().utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 0x0100_0193
        }
        return Int(hash % UInt32(count))
    }

    /// The tone an author's initials are drawn on.
    public static func tone(_ name: String) -> Tone {
        tones[colorIndex(name, count: tones.count)]
    }
}

extension KeyedDecodingContainer {
    /// `true`, `1` or `"true"`; anything else, or nothing, is false.
    fileprivate func decodeFlag(forKey key: Key) -> Bool {
        if let flag = try? decode(Bool.self, forKey: key) { return flag }
        if let number = try? decode(Double.self, forKey: key) { return number != 0 }
        if let text = try? decode(String.self, forKey: key) { return ["true", "yes", "1"].contains(text.lowercased()) }
        return false
    }
}
