import AppKit
import TjuvkikCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let store = ConfigStore()
    private let trigger = FnTrigger()
    private lazy var glance = GlanceController(store: store)
    private var permissionPoll: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item

        store.onChange = { [weak self] config in self?.apply(config) }
        store.start()
        apply(store.config)
        updateIcon()

        trigger.onShow = { [glance] in glance.show() }
        trigger.onHide = { [glance] in glance.hide() }
        startTrigger()
        observeErrors()
    }

    private func apply(_ config: Config) {
        trigger.holdDuration = .milliseconds(config.holdMilliseconds)
    }

    /// A broken config shows as a warning sign in the menu bar until it's fixed.
    private func observeErrors() {
        withObservationTracking {
            _ = store.errors
        } onChange: {
            Task { @MainActor in
                self.updateIcon()
                self.observeErrors()
            }
        }
    }

    private func updateIcon() {
        let name = store.errors.isEmpty ? "square.grid.2x2" : "exclamationmark.triangle"
        let icon = NSImage(systemSymbolName: name, accessibilityDescription: "Tjuvkik")
        icon?.isTemplate = true
        statusItem?.button?.image = icon
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
            menu.addItem(disabled: "Hold fn to glance")
        } else {
            menu.addItem(disabled: "Tjuvkik needs Input Monitoring to see the fn key")
            menu.addItem(action: "Allow Input Monitoring…", target: self, #selector(openInputMonitoring))
        }

        if !store.errors.isEmpty {
            menu.addItem(.separator())
            menu.addItem(disabled: "Config error, using the last good config:")
            for issue in store.errors.prefix(8) { menu.addItem(disabled: issue.description, symbol: "xmark.octagon") }
        }
        if !store.warnings.isEmpty {
            menu.addItem(.separator())
            for issue in store.warnings.prefix(8) { menu.addItem(disabled: issue.description, symbol: "exclamationmark.triangle") }
        }

        menu.addItem(.separator())
        menu.addItem(action: "Open Config", target: self, #selector(openConfig), key: ",")
        menu.addItem(action: "Reload Config", target: self, #selector(reloadConfig), key: "r")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Tjuvkik", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func openInputMonitoring() {
        InputMonitoring.openSettings()
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(store.fileURL)
    }

    @objc private func reloadConfig() {
        store.reload()
    }
}

private extension NSMenu {
    func addItem(disabled title: String, symbol: String? = nil) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        addItem(item)
    }

    func addItem(action title: String, target: AnyObject, _ selector: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = target
        addItem(item)
    }
}
