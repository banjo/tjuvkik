import Foundation

/// What else, besides a script's `notify`, sends a notification.
public enum NotifyEvent: String, CaseIterable, Sendable {
    /// While the panel shows an error.
    case failed
    /// A row with this tone.
    case warning, error

    init?(tone: Tone) {
        switch tone {
        case .warning: self = .warning
        case .error: self = .error
        default: return nil
        }
    }
}

/// A panel's `notify`.
public struct NotifySettings: Equatable, Sendable {
    public var sound: Bool?          // nil: the global setting
    public var minInterval: Double   // seconds, 0: no limit
    public var on: Set<NotifyEvent>

    public init(sound: Bool? = nil, minInterval: Double = 0, on: Set<NotifyEvent> = []) {
        self.sound = sound
        self.minInterval = minInterval
        self.on = on
    }
}

/// `config.jsonc`'s `notifications`.
public struct NotificationSettings: Equatable, Sendable {
    public var enabled: Bool
    public var sound: Bool
    public var quietHours: QuietHours?
    public var whileOpen: Bool

    public init(enabled: Bool = true, sound: Bool = true, quietHours: QuietHours? = nil, whileOpen: Bool = false) {
        self.enabled = enabled
        self.sound = sound
        self.quietHours = quietHours
        self.whileOpen = whileOpen
    }
}

/// `"22:00-07:00"`: a daily span in local time. It may cross midnight.
public struct QuietHours: Equatable, Sendable {
    /// Minutes after midnight.
    public var start: Int
    public var end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }

    /// `"HH:mm-HH:mm"`, 24-hour. Nil if it can't be read, or if start and end are the same.
    public static func parse(_ text: String) -> QuietHours? {
        let halves = text.split(separator: "-", omittingEmptySubsequences: false)
        guard halves.count == 2, let start = minutes(halves[0]), let end = minutes(halves[1]), start != end else { return nil }
        return QuietHours(start: start, end: end)
    }

    private static func minutes(_ text: Substring) -> Int? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let hour = Int(parts[0].trimmingCharacters(in: .whitespaces)), (0...23).contains(hour),
              let minute = Int(parts[1].trimmingCharacters(in: .whitespaces)), (0...59).contains(minute)
        else { return nil }
        return hour * 60 + minute
    }

    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return start < end ? (start..<end).contains(minute) : (minute >= start || minute < end)
    }
}
