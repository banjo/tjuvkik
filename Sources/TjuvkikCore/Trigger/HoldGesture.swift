/// Turns fn key events into show and hide. Holding fn alone for the hold time shows the glance and
/// letting go hides it. Any other key or modifier while fn is down cancels, so fn+arrows and
/// fn+F-keys never flash the glance.
public struct HoldGesture: Sendable {
    public enum Event: Sendable {
        case fnDown(otherModifiers: Bool)
        case fnUp
        case keyDown
        case modifiersChanged
        case timerFired
    }

    public enum Effect: Equatable, Sendable {
        case startTimer
        case cancelTimer
        case show
        case hide
    }

    enum Phase: Equatable {
        case idle
        case pending
        case shown
        /// fn is still down, but this press can no longer show the glance.
        case cancelled
    }

    private(set) var phase = Phase.idle

    public init() {}

    public var isShown: Bool { phase == .shown }

    public mutating func handle(_ event: Event) -> [Effect] {
        switch (event, phase) {
        case (.fnDown(let otherModifiers), .idle):
            if otherModifiers {
                phase = .cancelled
                return []
            }
            phase = .pending
            return [.startTimer]
        case (.fnDown, _):
            return []

        case (.timerFired, .pending):
            phase = .shown
            return [.show]
        case (.timerFired, _):
            return []

        case (.keyDown, .pending), (.modifiersChanged, .pending):
            phase = .cancelled
            return [.cancelTimer]
        case (.keyDown, .shown), (.modifiersChanged, .shown):
            phase = .cancelled
            return [.hide]
        case (.keyDown, _), (.modifiersChanged, _):
            return []

        case (.fnUp, .pending):
            phase = .idle
            return [.cancelTimer]
        case (.fnUp, .shown):
            phase = .idle
            return [.hide]
        case (.fnUp, _):
            phase = .idle
            return []
        }
    }
}
