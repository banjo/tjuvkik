import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let trigger = FnTrigger()
    private let glance = GlanceController()
    private var permissionPoll: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Tjuvkik")
        icon?.isTemplate = true
        item.button?.image = icon
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item

        trigger.onShow = { [glance] in glance.show() }
        trigger.onHide = { [glance] in glance.hide() }
        startTrigger()
    }

    private func startTrigger() {
        if trigger.start() { return }
        InputMonitoring.request()
        // Granting happens in System Settings; start as soon as it's done.
        permissionPoll = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            MainActor.assumeIsolated {
                guard self.trigger.start() else { return }
                self.permissionPoll?.invalidate()
                self.permissionPoll = nil
            }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if trigger.isRunning {
            menu.addItem(withTitle: "Hold fn to glance", action: nil, keyEquivalent: "")
        } else {
            menu.addItem(withTitle: "Tjuvkik needs Input Monitoring to see the fn key", action: nil, keyEquivalent: "")
            let allow = NSMenuItem(title: "Allow Input Monitoring…", action: #selector(openInputMonitoring), keyEquivalent: "")
            allow.target = self
            menu.addItem(allow)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Tjuvkik", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func openInputMonitoring() {
        InputMonitoring.openSettings()
    }
}
