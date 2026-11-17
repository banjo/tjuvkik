import AppKit
import TjuvkikCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let store = ConfigStore()
    private let panels = PanelStore()
    private let pause = PauseMonitor()
    private let notifier = Notifier()
    private let trigger = GlanceTrigger()
    private lazy var glance = GlanceController(store: store, panels: panels)
    private lazy var settings = SettingsWindowController(model: SettingsModel(store: store, panels: panels))
    private var permissionPoll: Timer?
    private var terminationSignal: (any DispatchSourceSignal)?
    private var launchAtLoginError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item

        quitOnTerminationSignal()
        trigger.onShow = { [weak self] in
            guard let self else { return }
            glance.show()
            settings.model.lastTriggered = Date()
        }
        trigger.onHide = { [glance] in glance.hide() }
        store.onChange = { [weak self] config in self?.apply(config) }
        pause.onChange = { [weak self] in
            guard let self else { return }
            panels.paused = pause.reason != nil
            // Coming back runs whatever is overdue.
            panels.refreshDue()
        }
        pause.start()
        store.start()
        notifier.onCommand = { [panels] command, id in panels.runAction(command, id: id) }
        notifier.onPermissionChange = { [weak self] permission in self?.settings.model.notificationsDenied = permission == .denied }
        panels.onChange = { [weak self] id in
            guard let self, let tile = panels.tiles.first(where: { $0.id == id }), let state = panels.states[id] else { return }
            notifier.update(id: id, tile: tile, state: state, config: store.config, glanceOpen: panels.glanceOpen)
        }
        notifier.start()
        panels.start()
        apply(store.config)
        glance.onShow = { [panels] in
            panels.glanceOpen = true
            panels.refreshDue()
        }
        glance.onHide = { [panels] in panels.glanceOpen = false }
        updateIcon()
        observeMenuBarPanel()
        observeErrors()
    }

    func applicationWillTerminate(_ notification: Notification) {
        panels.stopAll()
    }

    /// `pkill` and logout send SIGTERM, which would skip applicationWillTerminate and leave
    /// stream panels' commands running.
    private func quitOnTerminationSignal() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { NSApp.terminate(nil) }
        source.resume()
        terminationSignal = source
    }

    private func apply(_ config: Config) {
        trigger.configure(config.trigger)
        startTrigger()
        panels.update(config.tiles)
        notifier.keep(Set(config.tiles.filter { $0.slot != nil || !$0.show }.map(\.id)))
        pause.configure(config.pause)
        launchAtLoginError = LaunchAtLogin.apply(config.launchAtLogin)
        updateIcon()
    }

    private var menuBarPanels: MenuBarPanels {
        MenuBarPanels(config: store.config, panels: panels)
    }

    private func observeMenuBarPanel() {
        withObservationTracking {
            _ = menuBarPanels.title
        } onChange: {
            Task { @MainActor in
                self.updateIcon()
                self.observeMenuBarPanel()
            }
        }
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

    /// The grid, or a warning sign while the config is broken. What the `menuBar` panels show
    /// replaces the grid: "❓ 2  ⇡ 3".
    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let title = menuBarPanels.title
        let symbol: String? = !store.errors.isEmpty ? "exclamationmark.triangle" : (title.length == 0 ? "square.grid.2x2" : nil)
        let icon = symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: "Tjuvkik") }
        icon?.isTemplate = true
        button.image = icon
        button.imagePosition = .imageLeading
        button.attributedTitle = title.length > 0 && icon != nil
            ? NSAttributedString(string: " ").appending(title)
            : title
    }

    /// Starts watching the trigger. A key needs Input Monitoring: ask, and start once it's granted.
    private func startTrigger() {
        if trigger.start() {
            permissionPoll?.invalidate()
            permissionPoll = nil
            return
        }
        guard permissionPoll == nil else { return }
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
        notifier.refreshPermission()
        menu.removeAllItems()
        menuBarPanels.addItems(to: menu, target: self, perform: #selector(performRow(_:)))
        if let error = trigger.shortcutError {
            menu.addItem(disabled: "\(error). Pick another \"shortcut\" in config.jsonc", symbol: "exclamationmark.triangle")
        } else if trigger.needsInputMonitoring, case .key(let key) = trigger.trigger.input {
            menu.addItem(disabled: "Tjuvkik needs Input Monitoring to see \(key == .fn ? "the fn key" : key.name)")
            menu.addItem(action: "Allow Input Monitoring…", target: self, #selector(openInputMonitoring))
        } else {
            menu.addItem(disabled: "\(trigger.trigger.instruction) to glance")
            if case .key(.fn) = trigger.trigger.input, trigger.trigger.mode == .doubleTap {
                menu.addItem(disabled: "If double-tapping fn starts dictation, change its shortcut")
                menu.addItem(action: "Open Keyboard Settings…", target: self, #selector(openKeyboardSettings))
            }
        }
        if let reason = pause.reason {
            menu.addItem(disabled: "Background runs paused: \(reason.rawValue)", symbol: "pause.circle")
        }
        if notifier.permission == .denied, store.config.notifications.enabled {
            menu.addItem(disabled: "Notifications are off for Tjuvkik", symbol: "bell.slash")
            menu.addItem(action: "Open Notification Settings…", target: self, #selector(openNotificationSettings))
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

        if LaunchAtLogin.needsApproval {
            menu.addItem(.separator())
            menu.addItem(disabled: "Launch at login is waiting for your approval")
            menu.addItem(action: "Open Login Items…", target: self, #selector(openLoginItems))
        } else if let launchAtLoginError {
            menu.addItem(.separator())
            menu.addItem(disabled: launchAtLoginError, symbol: "exclamationmark.triangle")
        }

        if let submenu = panelMenu() {
            menu.addItem(.separator())
            menu.addItem(submenu)
        }

        menu.addItem(.separator())
        menu.addItem(action: "Settings…", target: self, #selector(openSettings), key: ",")
        menu.addItem(action: "Open Config", target: self, #selector(openConfig))
        menu.addItem(action: "Show Config Folder", target: self, #selector(showConfigFolder))
        menu.addItem(action: "Reload Config", target: self, #selector(reloadConfig), key: "r")
        menu.addItem(.separator())
        menu.addItem(action: "Export Config…", target: self, #selector(exportConfig))
        menu.addItem(action: "Import Config…", target: self, #selector(importConfig))
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Tjuvkik", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func openInputMonitoring() {
        InputMonitoring.openSettings()
    }

    @objc private func openKeyboardSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
    }

    @objc private func openNotificationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
    }

    /// Each panel and what it last did, for the menu. Left out when there are no panels.
    private func panelMenu() -> NSMenuItem? {
        guard !panels.tiles.isEmpty else { return nil }
        let item = NSMenuItem(title: "Panels", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        item.submenu = submenu
        for tile in panels.tiles {
            submenu.addItem(disabled: "\(tile.title): \(status(of: tile))")
        }
        return item
    }

    private func status(of tile: Tile) -> String {
        if tile.mode == .stream { return "live" }
        if let file = tile.file { return "watches \(file.lastPathComponent)" }
        guard let lastRun = panels.states[tile.id]?.lastRun else {
            return tile.background == .off ? "runs when you glance" : "not run yet"
        }
        var status = "ran \(lastRun.formatted(.relative(presentation: .named)))"
        if tile.background == .off { status += ", only when you glance" }
        if !tile.show { status += ", not on the board" }
        return status
    }

    @objc private func performRow(_ item: NSMenuItem) {
        switch item.representedObject as? MenuBarPanels.Action {
        case .open(let link): NSWorkspace.shared.open(link)
        case .run(let command, let id): panels.runAction(command, id: id)
        case nil: break
        }
    }

    @objc private func openLoginItems() {
        LaunchAtLogin.openSettings()
    }

    @objc private func openSettings() {
        notifier.refreshPermission()
        settings.show()
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(store.configFile)
    }

    @objc private func showConfigFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([store.configFile])
    }

    @objc private func exportConfig() {
        ConfigTransfer.export(store)
    }

    @objc private func importConfig() {
        ConfigTransfer.import(store)
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
