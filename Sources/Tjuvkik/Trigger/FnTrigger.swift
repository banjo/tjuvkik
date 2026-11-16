import AppKit
import CoreGraphics
import TjuvkikCore

/// Watches the fn key with a listen-only event tap and reports when the glance should show or hide.
/// Listen-only means it never swallows or delays a key.
@MainActor
final class FnTrigger {
    var holdDuration: Duration = .milliseconds(250)
    var onShow: () -> Void = {}
    var onHide: () -> Void = {}

    private var gesture = HoldGesture()
    private var timer: Task<Void, Never>?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    private static let fnKeyCode: Int64 = 63
    private static let otherModifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

    var isRunning: Bool { tap != nil }

    /// Returns false if the tap couldn't be created, which means Input Monitoring isn't granted.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: fnTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    fileprivate func handle(type: CGEventType, keyCode: Int64, flags: CGEventFlags) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .flagsChanged where keyCode == Self.fnKeyCode:
            if flags.contains(.maskSecondaryFn) {
                send(.fnDown(otherModifiers: !flags.isDisjoint(with: Self.otherModifiers)))
            } else {
                send(.fnUp)
            }
        case .flagsChanged:
            send(.modifiersChanged)
        case .keyDown:
            send(.keyDown)
        default:
            break
        }
    }

    private func send(_ event: HoldGesture.Event) {
        for effect in gesture.handle(event) {
            switch effect {
            case .startTimer:
                timer?.cancel()
                timer = Task { [weak self, holdDuration] in
                    try? await Task.sleep(for: holdDuration)
                    guard !Task.isCancelled else { return }
                    self?.send(.timerFired)
                }
            case .cancelTimer:
                timer?.cancel()
                timer = nil
            case .show:
                onShow()
            case .hide:
                onHide()
            }
        }
    }
}

private func fnTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let userInfo {
        let address = UInt(bitPattern: userInfo)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        // The tap's run loop source is on the main run loop.
        MainActor.assumeIsolated {
            let trigger = Unmanaged<FnTrigger>.fromOpaque(UnsafeRawPointer(bitPattern: address)!).takeUnretainedValue()
            trigger.handle(type: type, keyCode: keyCode, flags: flags)
        }
    }
    return Unmanaged.passUnretained(event)
}
