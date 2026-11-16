/// Turns the trigger's key events into show and hide.
///
/// Hold: holding the trigger alone for the hold time shows the glance, letting go hides it. Any
/// other key or modifier while it's down cancels, so fn+arrows and ⌥+letters never flash it.
///
/// Toggle: tapping the trigger alone shows or hides the glance, and so does a shortcut's press.
/// A key or another modifier during the tap cancels it. Esc hides.
public struct TriggerGesture: Sendable {
    public enum Event: Sendable, Equatable {
        case triggerDown(otherModifiers: Bool)
        case triggerUp
        /// Another key was pressed.
        case otherKey
        /// Another modifier changed.
        case modifiersChanged
        case timerFired
        /// A toggle shortcut was pressed.
        case toggle
        /// Esc, while the glance shows.
        case dismiss
    }

    public enum Effect: Equatable, Sendable {
        case startTimer
        case cancelTimer
        case show
        case hide
    }

    enum Press: Equatable {
        case idle
        case pending
        case held
        /// The trigger is still down, but this press can no longer do anything.
        case cancelled
    }

    public let mode: Trigger.Mode
    private(set) var press = Press.idle
    public private(set) var isShown = false

    public init(mode: Trigger.Mode = .hold) {
        self.mode = mode
    }

    public mutating func handle(_ event: Event) -> [Effect] {
        switch mode {
        case .hold: hold(event)
        case .toggle: toggle(event)
        }
    }

    private mutating func hold(_ event: Event) -> [Effect] {
        switch (event, press) {
        case (.triggerDown(let otherModifiers), .idle):
            press = otherModifiers ? .cancelled : .pending
            return otherModifiers ? [] : [.startTimer]
        case (.triggerDown, _):
            return []

        case (.timerFired, .pending):
            press = .held
            return show()
        case (.timerFired, _):
            return []

        case (.otherKey, .pending), (.modifiersChanged, .pending):
            press = .cancelled
            return [.cancelTimer]
        case (.otherKey, .held), (.modifiersChanged, .held), (.dismiss, .held):
            press = .cancelled
            return hide()
        case (.otherKey, _), (.modifiersChanged, _), (.dismiss, _), (.toggle, _):
            return []

        case (.triggerUp, .pending):
            press = .idle
            return [.cancelTimer]
        case (.triggerUp, _):
            press = .idle
            return hide()
        }
    }

    private mutating func toggle(_ event: Event) -> [Effect] {
        switch (event, press) {
        case (.triggerDown(let otherModifiers), .idle):
            press = otherModifiers ? .cancelled : .pending
            return []
        case (.triggerDown, _):
            return []

        case (.otherKey, .pending), (.modifiersChanged, .pending):
            press = .cancelled
            return []
        case (.otherKey, _), (.modifiersChanged, _), (.timerFired, _):
            return []

        case (.triggerUp, .pending):
            press = .idle
            return isShown ? hide() : show()
        case (.triggerUp, _):
            press = .idle
            return []

        case (.toggle, _):
            return isShown ? hide() : show()
        case (.dismiss, _):
            return hide()
        }
    }

    private mutating func show() -> [Effect] {
        isShown = true
        return [.show]
    }

    /// Hides, if shown.
    private mutating func hide() -> [Effect] {
        guard isShown else { return [] }
        isShown = false
        return [.hide]
    }
}
