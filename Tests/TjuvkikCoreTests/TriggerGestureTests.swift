import Testing
@testable import TjuvkikCore

struct TriggerGestureTests {
    @Test func holdShowsAndReleaseHides() {
        var g = TriggerGesture()
        #expect(g.handle(.triggerDown(otherModifiers: false)) == [.startTimer])
        #expect(g.handle(.timerFired) == [.show])
        #expect(g.isShown)
        #expect(g.handle(.triggerUp) == [.hide])
        #expect(!g.isShown)
    }

    @Test func quickTapNeverShows() {
        var g = TriggerGesture()
        _ = g.handle(.triggerDown(otherModifiers: false))
        #expect(g.handle(.triggerUp) == [.cancelTimer])
        #expect(g.handle(.timerFired) == [])
    }

    @Test func keyBeforeTimerCancels() {
        var g = TriggerGesture()
        _ = g.handle(.triggerDown(otherModifiers: false))
        #expect(g.handle(.otherKey) == [.cancelTimer])
        #expect(g.handle(.timerFired) == [])
        #expect(g.handle(.triggerUp) == [])
    }

    @Test func keyWhileShownHides() {
        var g = TriggerGesture()
        _ = g.handle(.triggerDown(otherModifiers: false))
        _ = g.handle(.timerFired)
        #expect(g.handle(.otherKey) == [.hide])
        #expect(g.handle(.triggerUp) == [])
    }

    @Test func otherModifierCancels() {
        var g = TriggerGesture()
        _ = g.handle(.triggerDown(otherModifiers: false))
        #expect(g.handle(.modifiersChanged) == [.cancelTimer])
        #expect(g.handle(.timerFired) == [])
    }

    @Test func triggerWithModifierHeldDoesNothing() {
        var g = TriggerGesture()
        #expect(g.handle(.triggerDown(otherModifiers: true)) == [])
        #expect(g.handle(.timerFired) == [])
        #expect(g.handle(.triggerUp) == [])
    }

    @Test func repeatedTriggerDownIsIgnored() {
        var g = TriggerGesture()
        _ = g.handle(.triggerDown(otherModifiers: false))
        #expect(g.handle(.triggerDown(otherModifiers: false)) == [])
        #expect(g.handle(.timerFired) == [.show])
    }

    @Test func worksAgainAfterCancel() {
        var g = TriggerGesture()
        _ = g.handle(.triggerDown(otherModifiers: false))
        _ = g.handle(.otherKey)
        _ = g.handle(.triggerUp)
        #expect(g.handle(.triggerDown(otherModifiers: false)) == [.startTimer])
    }

    @Test func holdIgnoresToggleAndEscHides() {
        var g = TriggerGesture()
        #expect(g.handle(.toggle) == [])
        _ = g.handle(.triggerDown(otherModifiers: false))
        _ = g.handle(.timerFired)
        #expect(g.handle(.dismiss) == [.hide])
        #expect(g.handle(.triggerUp) == [])
    }

    @Test func tapToggles() {
        var g = TriggerGesture(mode: .toggle)
        #expect(g.handle(.triggerDown(otherModifiers: false)) == [])
        #expect(g.handle(.triggerUp) == [.show])
        #expect(g.handle(.otherKey) == [])
        #expect(g.isShown)
        _ = g.handle(.triggerDown(otherModifiers: false))
        #expect(g.handle(.triggerUp) == [.hide])
    }

    @Test func tapWithAKeyDoesNothing() {
        var g = TriggerGesture(mode: .toggle)
        _ = g.handle(.triggerDown(otherModifiers: false))
        _ = g.handle(.otherKey)
        #expect(g.handle(.triggerUp) == [])
        #expect(g.handle(.triggerDown(otherModifiers: true)) == [])
        #expect(g.handle(.triggerUp) == [])
        #expect(!g.isShown)
    }

    @Test func shortcutTogglesAndEscHides() {
        var g = TriggerGesture(mode: .toggle)
        #expect(g.handle(.toggle) == [.show])
        #expect(g.handle(.toggle) == [.hide])
        #expect(g.handle(.toggle) == [.show])
        #expect(g.handle(.dismiss) == [.hide])
        #expect(g.handle(.dismiss) == [])
    }

    // MARK: Double tap

    private let d = TriggerGesture.Event.triggerDown(otherModifiers: false)
    private let u = TriggerGesture.Event.triggerUp

    @Test func doubleTapShowsAndHides() {
        var g = TriggerGesture(mode: .doubleTap)
        #expect(g.handle(d) == [.startTimer])
        #expect(g.handle(u) == [])
        #expect(g.handle(d) == [.cancelTimer, .show])
        #expect(g.handle(u) == [])
        #expect(g.isShown)
        #expect(g.handle(d) == [.startTimer])
        #expect(g.handle(u) == [])
        #expect(g.handle(d) == [.cancelTimer, .hide])
    }

    @Test func singleTapDoesNothing() {
        var g = TriggerGesture(mode: .doubleTap)
        _ = g.handle(d)
        _ = g.handle(u)
        #expect(g.handle(.timerFired) == [])
        #expect(!g.isShown)
        #expect(g.handle(d) == [.startTimer])
    }

    @Test func slowSecondTapStartsOver() {
        var g = TriggerGesture(mode: .doubleTap)
        _ = g.handle(d)
        _ = g.handle(u)
        _ = g.handle(.timerFired)
        #expect(g.handle(d) == [.startTimer])
    }

    @Test func heldFirstPressDoesNotCount() {
        var g = TriggerGesture(mode: .doubleTap)
        _ = g.handle(d)
        #expect(g.handle(.timerFired) == [])
        #expect(g.handle(u) == [])
        #expect(g.handle(d) == [.startTimer])
        _ = g.handle(u)
        #expect(g.handle(d) == [.cancelTimer, .show])
    }

    @Test func keyBetweenTapsCancels() {
        var g = TriggerGesture(mode: .doubleTap)
        _ = g.handle(d)
        _ = g.handle(u)
        #expect(g.handle(.otherKey) == [.cancelTimer])
        #expect(g.handle(d) == [.startTimer])
    }

    @Test func modifierOnSecondPressCancels() {
        var g = TriggerGesture(mode: .doubleTap)
        _ = g.handle(d)
        _ = g.handle(u)
        #expect(g.handle(.triggerDown(otherModifiers: true)) == [.cancelTimer])
        #expect(g.handle(u) == [])
        #expect(!g.isShown)
    }

    @Test func keyDuringFirstPressCancels() {
        var g = TriggerGesture(mode: .doubleTap)
        _ = g.handle(d)
        #expect(g.handle(.otherKey) == [.cancelTimer])
        #expect(g.handle(u) == [])
        #expect(g.handle(d) == [.startTimer])
    }

    @Test func doubleTapKeysDontHideAndEscDoes() {
        var g = TriggerGesture(mode: .doubleTap)
        _ = g.handle(d)
        _ = g.handle(u)
        _ = g.handle(d)
        _ = g.handle(u)
        #expect(g.handle(.otherKey) == [])
        #expect(g.isShown)
        #expect(g.handle(.dismiss) == [.hide])
        #expect(g.handle(.dismiss) == [])
    }

    @Test func holdingSecondPressKeepsShowing() {
        var g = TriggerGesture(mode: .doubleTap)
        _ = g.handle(d)
        _ = g.handle(u)
        _ = g.handle(d)
        #expect(g.handle(.timerFired) == [])
        #expect(g.handle(u) == [])
        #expect(g.isShown)
    }

    @Test func doubleTapIgnoresToggle() {
        var g = TriggerGesture(mode: .doubleTap)
        #expect(g.handle(.toggle) == [])
    }
}

struct TriggerKeyTests {
    @Test func fnAlone() {
        #expect(Trigger.Key.fn.event(keyCode: 63, flags: 0x800000) == .triggerDown(otherModifiers: false))
        #expect(Trigger.Key.fn.event(keyCode: 63, flags: 0x800000 | 0x100000) == .triggerDown(otherModifiers: true))
        #expect(Trigger.Key.fn.event(keyCode: 63, flags: 0) == .triggerUp)
        #expect(Trigger.Key.fn.event(keyCode: 55, flags: 0x100000) == .modifiersChanged)
    }

    @Test func rightOptionIsToldFromLeft() {
        let option: UInt64 = 0x80000
        let key = Trigger.Key.rightOption
        #expect(key.event(keyCode: 61, flags: option | 0x40) == .triggerDown(otherModifiers: false))
        #expect(key.event(keyCode: 61, flags: option | 0x40 | 0x20) == .triggerDown(otherModifiers: true))
        #expect(key.event(keyCode: 58, flags: option | 0x20) == .modifiersChanged)
        // Released while the left one is still down.
        #expect(key.event(keyCode: 61, flags: option | 0x20) == .triggerUp)
    }

    @Test func rightCommandWithShift() {
        #expect(Trigger.Key.rightCommand.event(keyCode: 54, flags: 0x100000 | 0x10 | 0x20000) == .triggerDown(otherModifiers: true))
        #expect(Trigger.Key.rightCommand.event(keyCode: 54, flags: 0x100000 | 0x10) == .triggerDown(otherModifiers: false))
    }

    @Test func instructions() {
        #expect(Trigger.fn.instruction == "Hold fn")
        #expect(Trigger(input: .key(.rightOption), mode: .toggle).instruction == "Tap right ⌥")
        #expect(Trigger(input: .key(.fn), mode: .doubleTap).instruction == "Double-tap fn")
        let shortcut = try! Shortcut.parse("ctrl+opt+space").get()
        #expect(Trigger(input: .shortcut(shortcut), mode: .toggle).instruction == "Press ⌃⌥Space")
        #expect(Trigger(input: .shortcut(shortcut), mode: .hold).instruction == "Hold ⌃⌥Space")
    }
}

struct ShortcutTests {
    private func parse(_ text: String) -> String {
        switch Shortcut.parse(text) {
        case .success(let shortcut): "\(shortcut) \(shortcut.keyCode)"
        case .failure(let error): error.message
        }
    }

    @Test func readsSymbolsAndWords() {
        #expect(parse("⌃⌥Space") == "⌃⌥Space 49")
        #expect(parse("ctrl+option+space") == "⌃⌥Space 49")
        #expect(parse("Cmd + Shift + g") == "⇧⌘G 5")
        #expect(parse("⌘⇧+G") == "⇧⌘G 5")
        #expect(parse("alt+1") == "⌥1 18")
        #expect(parse("ctrl+up") == "⌃↑ 126")
        #expect(parse("⌥/") == "⌥/ 44")
    }

    @Test func functionKeysNeedNoModifier() {
        #expect(parse("F18") == "F18 79")
        #expect(parse("f5") == "F5 96")
        #expect(parse("shift+F1") == "⇧F1 122")
    }

    @Test func explainsWhatsWrong() {
        #expect(parse("") == "is empty")
        #expect(parse("space") == "needs ⌃, ⌥ or ⌘, so it doesn't take a key you type")
        #expect(parse("shift+a") == "needs ⌃, ⌥ or ⌘, so it doesn't take a key you type")
        #expect(parse("ctrl+") == "needs a key after the modifiers, like ⌃⌥Space")
        #expect(parse("ctrl+shift") == "needs a key after the modifiers, like ⌃⌥Space; to use a modifier on its own, set \"key\"")
        #expect(parse("hyper+space") == "\"hyper\" isn't a modifier, expected ctrl, option, shift or cmd")
        #expect(parse("ctrl+å") == "unknown key \"å\", expected a letter, a digit, Space, Return, Tab, an arrow or F1–F20")
        #expect(parse("ctrl+F21").hasPrefix("unknown key \"F21\""))
    }
}
