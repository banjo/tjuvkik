import AppKit
import SwiftUI

/// The setup window: trigger, panels, theme and a few switches. Like the settings window, the
/// app has a Dock icon while it's open.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    let model: SettingsModel
    /// Called after Done closes the window, to show the glance once.
    var onDone: () -> Void = {}
    /// Set on first start: the panels step ticks the starters it starts with, once.
    var ticksStarters = false
    private var window: NSWindow?

    init(model: SettingsModel) {
        self.model = model
    }

    func show() {
        let window = self.window ?? makeWindow()
        if !(window.contentView is NSHostingView<OnboardingView>) {
            let view = NSHostingView(rootView: OnboardingView(
                model: model,
                tickStarters: { [weak self] in
                    guard let self, ticksStarters else { return false }
                    ticksStarters = false
                    return true
                },
                close: { [weak self] done in self?.close(done: done) }
            ))
            // The window keeps its size, title bar included.
            view.sizingOptions = []
            window.contentView = view
            Self.center(window)
            DockIcon.windowOpened()
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func close(done: Bool) {
        window?.close()
        if done { onDone() }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.setFrame(NSRect(x: 0, y: 0, width: 640, height: 560), display: false)
        window.title = "Welcome to Tjuvkik"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        return window
    }

    /// On the screen with the mouse.
    private static func center(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2))
    }

    func windowWillClose(_ notification: Notification) {
        // Dropping the views ends what they run, and the next open starts at step 1.
        window?.contentView = nil
        DockIcon.windowClosed()
    }
}
