/// What opens the glance: a modifier key on its own, or a shortcut.
public struct Trigger: Equatable, Sendable {
    /// A modifier key, held or tapped on its own.
    public enum Key: String, CaseIterable, Sendable {
        case fn, rightOption, rightCommand, rightControl, rightShift
    }

    public enum Mode: String, CaseIterable, Sendable {
        /// Shows while held, hides on release.
        case hold
        /// A press shows, the next press or Esc hides.
        case toggle
        /// Two taps in a row show, two more or Esc hide. A single tap does nothing.
        case doubleTap
    }

    public enum Input: Equatable, Sendable {
        case key(Key)
        case shortcut(Shortcut)
    }

    public var input: Input
    public var mode: Mode
    /// How long a hold takes before the glance shows.
    public var holdMilliseconds: Int
    /// How soon the second tap of a double tap must follow the first.
    public var doubleTapMilliseconds: Int
    /// A click outside an open glance, or between its tiles, closes it.
    public var closeOnClickOutside: Bool

    public init(input: Input, mode: Mode, holdMilliseconds: Int = 250, doubleTapMilliseconds: Int = 300, closeOnClickOutside: Bool = true) {
        self.input = input
        self.mode = mode
        self.holdMilliseconds = holdMilliseconds
        self.doubleTapMilliseconds = doubleTapMilliseconds
        self.closeOnClickOutside = closeOnClickOutside
    }

    public static let fn = Trigger(input: .key(.fn), mode: .hold)

    /// "Hold fn", "Tap right ⌥", "Press ⌃⌥Space".
    public var instruction: String {
        switch (input, mode) {
        case (.key(let key), .hold): "Hold \(key.name)"
        case (.key(let key), .toggle): "Tap \(key.name)"
        case (.key(let key), .doubleTap): "Double-tap \(key.name)"
        case (.shortcut(let shortcut), .hold): "Hold \(shortcut)"
        case (.shortcut(let shortcut), .toggle): "Press \(shortcut)"
        case (.shortcut(let shortcut), .doubleTap): "Press \(shortcut)"
        }
    }
}

extension Trigger.Key {
    /// "fn", "right ⌥".
    public var name: String {
        switch self {
        case .fn: "fn"
        case .rightOption: "right ⌥"
        case .rightCommand: "right ⌘"
        case .rightControl: "right ⌃"
        case .rightShift: "right ⇧"
        }
    }

    // The values of a `flagsChanged` event: the key's code, and flag bits as in `CGEventFlags`.
    // A right modifier has its own device bit, so it's told apart from the left one.

    static let shift: UInt64 = 0x20000
    static let control: UInt64 = 0x40000
    static let option: UInt64 = 0x80000
    static let command: UInt64 = 0x100000
    static let function: UInt64 = 0x800000

    var keyCode: Int64 {
        switch self {
        case .fn: 63
        case .rightOption: 61
        case .rightCommand: 54
        case .rightControl: 62
        case .rightShift: 60
        }
    }

    /// The bit that's set while this key is down.
    var downBit: UInt64 {
        switch self {
        case .fn: Self.function
        case .rightOption: 0x40
        case .rightCommand: 0x10
        case .rightControl: 0x2000
        case .rightShift: 0x04
        }
    }

    /// Bits that mean another modifier is down: the other kinds, and this kind's left key.
    var otherBits: UInt64 {
        switch self {
        case .fn: Self.shift | Self.control | Self.option | Self.command
        case .rightOption: Self.shift | Self.control | Self.command | Self.function | 0x20
        case .rightCommand: Self.shift | Self.control | Self.option | Self.function | 0x08
        case .rightControl: Self.shift | Self.option | Self.command | Self.function | 0x01
        case .rightShift: Self.control | Self.option | Self.command | Self.function | 0x02
        }
    }

    /// What a modifier changing means for this trigger.
    public func event(keyCode: Int64, flags: UInt64) -> TriggerGesture.Event {
        guard keyCode == self.keyCode else { return .modifiersChanged }
        guard flags & downBit != 0 else { return .triggerUp }
        return .triggerDown(otherModifiers: flags & otherBits != 0)
    }
}
