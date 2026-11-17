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
        }
        NSApp.setActivationPolicy(.regular)
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
        if NSApp.mainMenu == nil { NSApp.mainMenu = Self.mainMenu() }
        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        // Dropping the views ends what they run, like a shortcut being recorded.
        window?.contentView = nil
        NSApp.setActivationPolicy(.accessory)
    }

    /// While the app is in the Dock it shows a menu bar, and text fields need Edit's key equivalents.
    private static func mainMenu() -> NSMenu {
        let menu = NSMenu()
        let app = NSMenu()
        app.addItem(withTitle: "Hide Tjuvkik", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Quit Tjuvkik", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        for submenu in [app, edit, window] {
            let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
            item.submenu = submenu
            menu.addItem(item)
        }
        return menu
    }
}
