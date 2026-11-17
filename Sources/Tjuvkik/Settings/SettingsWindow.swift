import AppKit
import SwiftUI

/// The settings window. While it's open the app has a Dock icon, so ⌘Tab reaches it.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    let model: SettingsModel
    private var window: NSWindow?

    init(model: SettingsModel) {
        self.model = model
    }

    func show() {
        let window = self.window ?? makeWindow()
        if !(window.contentView is NSHostingView<SettingsView>) {
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            DockIcon.windowOpened()
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = "Tjuvkik Settings"
        window.minSize = NSSize(width: 760, height: 520)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("Settings")
        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        // Dropping the views ends what they run, like a shortcut being recorded.
        window?.contentView = nil
        DockIcon.windowClosed()
    }
}
