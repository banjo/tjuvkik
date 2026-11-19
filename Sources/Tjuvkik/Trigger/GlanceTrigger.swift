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
    var onPin: () -> Void = {}
    /// A key for moving around the glance, while it stays open.
    var onKey: (GlanceKey) -> Void = { _ in }
    /// Esc, before it closes the glance: true when it was used, like closing the ⌘K list.
    var onEscape: () -> Bool = { false }

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
    private static let spaceID: UInt32 = 3
    /// Keys taken while the glance stays open, from this ID up.
    private static let navigationID: UInt32 = 100
    /// The focused row's action keys, from this ID up.
    private static let rowKeyID: UInt32 = 200
    private var rowKeys: [String] = []
    private var takesNavigationKeys = false
    /// The navigation keys as registered, by their offset from `navigationID`.
    private var registeredKeys: [(keyCode: Int, modifiers: Int, key: GlanceKey)] = []
    /// Held with an arrow, it jumps to the next tile that way.
    var jumpKey = Config.JumpKey.option {
        didSet {
            guard jumpKey != oldValue, takesNavigationKeys else { return }
            releaseNavigationKeys()
            takeNavigationKeys()
        }
    }
    private var navigationKeys: [(keyCode: Int, modifiers: Int, key: GlanceKey)] {
        let arrows: [(Int, FocusNavigation.Direction)] = [
            (kVK_LeftArrow, .left), (kVK_RightArrow, .right), (kVK_UpArrow, .up), (kVK_DownArrow, .down),
        ]
        let jumps: [(keyCode: Int, modifiers: Int, key: GlanceKey)] = switch jumpKey {
        case .option: arrows.map { ($0, optionKey, .jump($1)) }
        case .command: arrows.map { ($0, cmdKey, .jump($1)) }
        case .control: arrows.map { ($0, controlKey, .jump($1)) }
        case .shift: arrows.map { ($0, shiftKey, .jump($1)) }
        case .none: []
        }
        return arrows.map { ($0, 0, .move($1)) } + [
            (kVK_Return, 0, .activate), (kVK_ANSI_KeypadEnter, 0, .activate), (kVK_Space, 0, .activate),
            (kVK_ANSI_R, cmdKey, .runNow), (kVK_ANSI_O, cmdKey, .openConfig),
            (kVK_ANSI_K, cmdKey, .menu), (kVK_ANSI_C, cmdKey, .copy),
            (kVK_Return, optionKey, .openURL), (kVK_ANSI_KeypadEnter, optionKey, .openURL),
            (kVK_Tab, 0, .nextTile), (kVK_Tab, shiftKey, .previousTile),
        ] + [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
            .enumerated().map { ($1, 0, .tile($0 + 1)) } + jumps
    }
    /// `NX_SYSDEFINED`, which `CGEventType` has no case for.
    private static let systemDefined: UInt32 = 14

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
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue) | (1 << Self.systemDefined)
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
        case _ where type.rawValue == Self.systemDefined:
            // Media keys (volume, brightness, play) come as system-defined events, not key downs.
            send(.otherKey)
        case .keyDown:
            // Space pins a held glance. The hot key that keeps it from the app in front only
            // swallows it after this tap has seen it.
            if keyCode == Int64(kVK_Space), gesture.isShown, trigger.mode == .hold {
                send(.pin)
            } else {
                send(.otherKey)
            }
        default:
            break
        }
    }

    // MARK: Shortcut

    private func hotKey(_ id: UInt32, pressed: Bool) {
        switch id {
        case Self.escapeID:
            if pressed, !onEscape() { send(.dismiss) }
        case Self.spaceID:
            if pressed { send(.pin) }
        case Self.shortcutID:
            // A held shortcut repeats its press.
            guard pressed != shortcutDown else { return }
            shortcutDown = pressed
            switch trigger.mode {
            case .hold: send(pressed ? .triggerDown(otherModifiers: false) : .triggerUp)
            case .toggle, .doubleTap: if pressed { send(.toggle) }
            }
        case Self.navigationID..<Self.navigationID + UInt32(registeredKeys.count):
            if pressed { onKey(registeredKeys[Int(id - Self.navigationID)].key) }
        case Self.rowKeyID..<Self.rowKeyID + UInt32(rowKeys.count):
            if pressed { onKey(.action(rowKeys[Int(id - Self.rowKeyID)])) }
        default:
            break
        }
    }

    /// Arrows, Tab, Enter, Space, ⌘R, ⌘O and 1–9 move around the glance while it stays open. They're
    /// taken from the app in front only then.
    private func takeNavigationKeys() {
        takesNavigationKeys = true
        registeredKeys = navigationKeys
        for (offset, entry) in registeredKeys.enumerated() {
            _ = hotKeys.register(Self.navigationID + UInt32(offset), keyCode: UInt32(entry.keyCode), modifiers: UInt32(entry.modifiers))
        }
        takeRowKeys()
    }

    private func releaseNavigationKeys() {
        takesNavigationKeys = false
        for offset in registeredKeys.indices { hotKeys.unregister(Self.navigationID + UInt32(offset)) }
        registeredKeys = []
        releaseRowKeys()
    }

    /// ⌘ and each key, for the focused row's actions, while the navigation keys are taken.
    func setRowKeys(_ keys: [String]) {
        guard keys != rowKeys else { return }
        releaseRowKeys()
        rowKeys = keys
        if takesNavigationKeys { takeRowKeys() }
    }

    private func takeRowKeys() {
        for (offset, key) in rowKeys.enumerated() {
            guard case .success(let shortcut) = Shortcut.parse("cmd+\(key)") else { continue }
            _ = hotKeys.register(Self.rowKeyID + UInt32(offset), keyCode: shortcut.keyCode, modifiers: shortcut.carbonModifiers)
        }
    }

    private func releaseRowKeys() {
        for offset in rowKeys.indices { hotKeys.unregister(Self.rowKeyID + UInt32(offset)) }
    }

    // MARK: Gesture

    /// A click in the glance.
    func pin() { send(.pin) }
    /// A click outside it, or a Space or app switch.
    func dismiss() { send(.dismiss) }
    /// Opens it pinned, for a notification click or after setup.
    func open() { send(.open) }

    private func send(_ event: TriggerGesture.Event) {
        for effect in gesture.handle(event) {
            switch effect {
            case .startTimer:
                timer?.cancel()
                let milliseconds = switch trigger.mode {
                case .hold: trigger.holdMilliseconds
                case .toggle: Trigger.tapMilliseconds
                case .doubleTap: trigger.doubleTapMilliseconds
                }
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
                // Space pins a held glance. If it's taken, a click still does.
                if trigger.mode == .hold { _ = hotKeys.register(Self.spaceID, keyCode: UInt32(kVK_Space), modifiers: spaceModifiers) }
                onShow()
                if trigger.mode != .hold { takeNavigationKeys() }
            case .pinned:
                hotKeys.unregister(Self.spaceID)
                _ = hotKeys.register(Self.escapeID, keyCode: UInt32(kVK_Escape), modifiers: 0)
                onPin()
                takeNavigationKeys()
            case .hide:
                hotKeys.unregister(Self.escapeID)
                hotKeys.unregister(Self.spaceID)
                releaseNavigationKeys()
                onHide()
            }
        }
    }

    /// The trigger's own modifier, held while Space is pressed.
    private var spaceModifiers: UInt32 {
        switch trigger.input {
        case .key(.fn): 0
        case .key(.rightOption): UInt32(optionKey)
        case .key(.rightCommand): UInt32(cmdKey)
        case .key(.rightControl): UInt32(controlKey)
        case .key(.rightShift): UInt32(shiftKey)
        case .shortcut(let shortcut): shortcut.carbonModifiers
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
