import AppKit
import Carbon.HIToolbox
import CoreGraphics
import TjuvkikCore

/// Reports when the glance should show or hide, from the configured trigger.
///
/// A modifier key is watched with a listen-only event tap, which never swallows or delays a key
/// but needs Input Monitoring. A shortcut is registered as a hot key, which needs no permission
/// and keeps the keystroke from the app in front.
@MainActor
final class GlanceTrigger {
    var onShow: () -> Void = {}
    var onHide: () -> Void = {}

    private(set) var trigger = Trigger.fn
    private var gesture = TriggerGesture()
    private var timer: Task<Void, Never>?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private lazy var hotKeys = HotKeys { [weak self] id, pressed in self?.hotKey(id, pressed: pressed) }
    private var shortcutDown = false
    /// Why the shortcut couldn't be registered.
    private(set) var shortcutError: String?

    private static let shortcutID: UInt32 = 1
    private static let escapeID: UInt32 = 2

    /// True when the trigger is watched: a key once Input Monitoring is granted, a shortcut once
    /// it's registered.
    var isRunning: Bool {
        switch trigger.input {
        case .key: tap != nil
        case .shortcut: hotKeys.isRegistered(Self.shortcutID)
        }
    }

    var needsInputMonitoring: Bool {
        if case .key = trigger.input { tap == nil } else { false }
    }

    /// Switches to a new trigger, hiding the glance if it shows. Call `start()` after.
    func configure(_ new: Trigger) {
        guard new != trigger else { return }
        stop()
        trigger = new
        gesture = TriggerGesture(mode: new.mode)
    }

    /// Returns false if a key's event tap couldn't be created, which means Input Monitoring isn't
    /// granted. A shortcut that's taken is recorded in `shortcutError`.
    @discardableResult
    func start() -> Bool {
        switch trigger.input {
        case .key: return startTap()
        case .shortcut(let shortcut):
            guard !hotKeys.isRegistered(Self.shortcutID) else { return true }
            let registered = hotKeys.register(Self.shortcutID, keyCode: shortcut.keyCode, modifiers: shortcut.carbonModifiers)
            shortcutError = registered ? nil : "\(shortcut) is taken by another app"
            return true
        }
    }

    private func stop() {
        if gesture.isShown { onHide() }
        timer?.cancel()
        timer = nil
        shortcutDown = false
        shortcutError = nil
        hotKeys.unregisterAll()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
            CFMachPortInvalidate(tap)
        }
        tap = nil
        source = nil
    }

    // MARK: Modifier key

    private func startTap() -> Bool {
        guard tap == nil else { return true }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: triggerTapCallback,
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
        guard case .key(let key) = trigger.input else { return }
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .flagsChanged:
            send(key.event(keyCode: keyCode, flags: flags.rawValue))
        case .keyDown:
            send(.otherKey)
        default:
            break
        }
    }

    // MARK: Shortcut

    private func hotKey(_ id: UInt32, pressed: Bool) {
        switch id {
        case Self.escapeID:
            if pressed { send(.dismiss) }
        case Self.shortcutID:
            // A held shortcut repeats its press.
            guard pressed != shortcutDown else { return }
            shortcutDown = pressed
            switch trigger.mode {
            case .hold: send(pressed ? .triggerDown(otherModifiers: false) : .triggerUp)
            case .toggle, .doubleTap: if pressed { send(.toggle) }
            }
        default:
            break
        }
    }

    // MARK: Gesture

    private func send(_ event: TriggerGesture.Event) {
        for effect in gesture.handle(event) {
            switch effect {
            case .startTimer:
                timer?.cancel()
                let milliseconds = trigger.mode == .doubleTap ? trigger.doubleTapMilliseconds : trigger.holdMilliseconds
                timer = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(milliseconds))
                    guard !Task.isCancelled else { return }
                    self?.send(.timerFired)
                }
            case .cancelTimer:
                timer?.cancel()
                timer = nil
            case .show:
                // Esc hides a toggled glance. It's only taken while the glance shows.
                if trigger.mode != .hold { _ = hotKeys.register(Self.escapeID, keyCode: UInt32(kVK_Escape), modifiers: 0) }
                onShow()
            case .hide:
                hotKeys.unregister(Self.escapeID)
                onHide()
            }
        }
    }
}

private func triggerTapCallback(
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
            let trigger = Unmanaged<GlanceTrigger>.fromOpaque(UnsafeRawPointer(bitPattern: address)!).takeUnretainedValue()
            trigger.handle(type: type, keyCode: keyCode, flags: flags)
        }
    }
    return Unmanaged.passUnretained(event)
}

extension Shortcut {
    var carbonModifiers: UInt32 {
        var flags = 0
        if modifiers.contains(.control) { flags |= controlKey }
        if modifiers.contains(.option) { flags |= optionKey }
        if modifiers.contains(.shift) { flags |= shiftKey }
        if modifiers.contains(.command) { flags |= cmdKey }
        return UInt32(flags)
    }
}

/// System-wide hot keys, through Carbon: the one API for them that needs no permission.
@MainActor
private final class HotKeys {
    private let onEvent: (UInt32, Bool) -> Void
    private var handler: EventHandlerRef?
    private var keys: [UInt32: EventHotKeyRef] = [:]
    /// "Tjvk"
    private static let signature: OSType = 0x546A_766B

    init(onEvent: @escaping (UInt32, Bool) -> Void) {
        self.onEvent = onEvent
    }

    func isRegistered(_ id: UInt32) -> Bool { keys[id] != nil }

    func register(_ id: UInt32, keyCode: UInt32, modifiers: UInt32) -> Bool {
        guard keys[id] == nil else { return true }
        installHandler()
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, EventHotKeyID(signature: Self.signature, id: id), GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        keys[id] = ref
        return true
    }

    func unregister(_ id: UInt32) {
        guard let ref = keys.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(ref)
    }

    func unregisterAll() {
        for id in Array(keys.keys) { unregister(id) }
    }

    private func installHandler() {
        guard handler == nil else { return }
        let types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(GetApplicationEventTarget(), hotKeyCallback, types.count, types, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    fileprivate func handle(_ id: EventHotKeyID, pressed: Bool) {
        guard id.signature == Self.signature else { return }
        onEvent(id.id, pressed)
    }
}

private func hotKeyCallback(_ call: EventHandlerCallRef?, _ event: EventRef?, _ userInfo: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let userInfo else { return OSStatus(eventNotHandledErr) }
    var id = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                   nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
    guard status == noErr else { return status }
    let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
    let address = UInt(bitPattern: userInfo)
    // Carbon delivers hot keys on the main thread.
    MainActor.assumeIsolated {
        Unmanaged<HotKeys>.fromOpaque(UnsafeRawPointer(bitPattern: address)!).takeUnretainedValue().handle(id, pressed: pressed)
    }
    return noErr
}
