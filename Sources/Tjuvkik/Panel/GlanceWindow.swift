import AppKit
import TjuvkikCore

/// The glance's window and the dim behind it, as the board and Spotlight both use them: shown and
/// faded out, and dismissed by a click outside or a Space or app switch.
@MainActor
final class GlanceWindow {
    let panel = GlancePanel()
    private let dim = DimWindow()
    private var hideGeneration = 0
    private var appearanceObservation: NSKeyValueObservation?
    private var workspaceObservers: [any NSObjectProtocol] = []
    private var outsideClicks: Any?
    private(set) var isShown = false
    /// True while it stays open on its own: toggled, or pinned.
    private(set) var isSticky = false
    /// A click outside, or between the tiles, dismisses a sticky glance.
    var closesOnClickOutside = true
    /// Tjuvkik was the active app when the glance stuck, as after setup: leaving it doesn't
    /// count as switching apps.
    private var stuckWhileActive = false

    /// A click outside, or a Space or app switch.
    var onDismiss: () -> Void = {}
    /// The system switched between light and dark.
    var onAppearanceChange: (Bool) -> Void = { _ in }

    var systemIsDark: Bool { Self.isDark(NSApp.effectiveAppearance) }

    init(content: NSView) {
        panel.contentView = content
        // KVO may call this off the main thread.
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { @Sendable [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.onAppearanceChange(self.systemIsDark)
            }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.isShown else { return }
                    self.onDismiss()
                }
            },
            workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                let isSelf = app?.processIdentifier == ProcessInfo.processInfo.processIdentifier
                MainActor.assumeIsolated {
                    guard let self, self.isSticky, !isSelf else { return }
                    if self.stuckWhileActive {
                        self.stuckWhileActive = false
                        return
                    }
                    self.onDismiss()
                }
            },
        ]
    }

    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    /// At `rect` on `screen`, with the screen behind it darkened by `dim`, from 0 to 1.
    func show(_ rect: CGRect, on screen: NSScreen, dim amount: Double) {
        hideGeneration += 1
        isShown = true
        panel.setFrame(rect, display: false)
        panel.alphaValue = 1
        panel.ignoresMouseEvents = false
        if amount > 0 {
            dim.setFrame(screen.frame, display: false)
            dim.orderFrontRegardless()
            fade(dim, to: amount, duration: 0.15)
        } else {
            dim.orderOut(nil)
        }
        panel.orderFrontRegardless()
    }

    /// After a pin: it stays open until a click outside or a Space or app switch. False when it
    /// isn't shown or already stuck.
    @discardableResult
    func stick() -> Bool {
        guard isShown, !isSticky else { return false }
        isSticky = true
        stuckWhileActive = NSApp.isActive
        guard closesOnClickOutside, outsideClicks == nil else { return true }
        // Only clicks that go to other apps reach a global monitor: exactly the ones outside.
        outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { @Sendable [weak self] _ in
            Task { @MainActor in
                guard let self, self.isSticky else { return }
                self.onDismiss()
            }
        }
        return true
    }

    /// Takes keyboard focus, without activating Tjuvkik: the app in front stays in front.
    func takeKeyboard() {
        panel.takesKeyboard = true
        panel.makeKey()
    }

    /// Fades out. `then` runs once it's gone, unless it was shown again meanwhile.
    func hide(then completion: @escaping @MainActor @Sendable () -> Void) {
        hideGeneration += 1
        isShown = false
        isSticky = false
        stuckWhileActive = false
        panel.ignoresMouseEvents = true
        if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
        outsideClicks = nil
        // Back to the app in front, which never stopped being active.
        if panel.isKeyWindow { panel.resignKey() }
        panel.takesKeyboard = false
        let generation = hideGeneration
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
            if dim.isVisible { dim.animator().alphaValue = 0 }
        } completionHandler: {
            MainActor.assumeIsolated {
                // A show during the fade wins.
                guard generation == self.hideGeneration else { return }
                self.panel.orderOut(nil)
                self.dim.orderOut(nil)
                completion()
            }
        }
    }

    /// At once with Reduce Motion on.
    private func fade(_ window: NSWindow, to alpha: CGFloat, duration: TimeInterval) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return window.alphaValue = alpha }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            window.animator().alphaValue = alpha
        }
    }
}
