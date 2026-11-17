import AppKit
import TjuvkikCore
@preconcurrency import UserNotifications

/// Delivers panels' notifications through Notification Center, and handles clicks on them.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    enum Permission { case unknown, granted, denied }

    private(set) var permission = Permission.unknown
    /// Runs a clicked notification's command: `(command, panel)`.
    var onCommand: (String, String) -> Void = { _, _ in }

    private let center: UNUserNotificationCenter?
    // Per panel, replaced on each update and removed with the panel.
    private var planners: [String: NotificationPlanner] = [:]
    private var signatures: [String: String] = [:]
    private var tiles: [String: Tile] = [:]
    private var settings = NotificationSettings()
    private var timer: Timer?
    private var requesting = false
    /// Requests made before macOS answered whether Tjuvkik may notify.
    private var held: [UNNotificationRequest] = []

    override init() {
        // UNUserNotificationCenter.current() crashes outside an app bundle (swift run, tests).
        center = Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
        super.init()
        center?.delegate = self
    }

    func start() {
        refreshPermission()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.flushAll() }
        }
    }

    /// Forgets the panels that no longer run, and withdraws what they delivered.
    func keep(_ panels: Set<String>) {
        for panel in Set(planners.keys).union(tiles.keys).union(signatures.keys) where !panels.contains(panel) {
            forget(panel)
        }
    }

    func refreshPermission() {
        center?.getNotificationSettings { @Sendable settings in
            let status = settings.authorizationStatus
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .authorized, .provisional: permission = .granted
                case .denied: permission = .denied
                default: permission = .unknown
                }
            }
        }
    }

    /// Called when a panel's content or error changes.
    func update(panel: String, tile: Tile, state: PanelStore.State, config: Config, glanceOpen: Bool) {
        settings = config.notifications
        guard config.notifications.enabled, let notify = tile.notify else {
            forget(panel)
            return
        }
        let signature = "\(tile.command)|\(tile.directory.path)"
        if signatures[panel] != signature {
            withdraw(planners[panel]?.deliveredIDs ?? [], panel: panel)
            planners[panel] = NotificationPlanner()
            signatures[panel] = signature
        }
        tiles[panel] = tile

        let wanted = PanelNotifications.collect(content: state.content, error: state.error, title: tile.title, on: notify.on)
        let muted = (config.notifications.quietHours?.contains(Date()) ?? false) || (glanceOpen && !config.notifications.whileOpen)
        guard var planner = planners[panel] else { return }
        let actions = planner.update(wanted, now: Date(), muted: muted, minInterval: notify.minInterval, panelTitle: tile.title)
        planners[panel] = planner
        perform(actions, panel: panel, tile: tile)
    }

    private func flushAll() {
        let now = Date()
        for (panel, var planner) in planners {
            guard let tile = tiles[panel], let notify = tile.notify else { continue }
            let actions = planner.flush(now: now, minInterval: notify.minInterval, panelTitle: tile.title)
            guard !actions.isEmpty else { continue }
            planners[panel] = planner
            perform(actions, panel: panel, tile: tile)
        }
    }

    private func forget(_ panel: String) {
        withdraw(planners[panel]?.deliveredIDs ?? [], panel: panel)
        planners[panel] = nil
        signatures[panel] = nil
        tiles[panel] = nil
    }

    // MARK: Delivering

    private func perform(_ actions: [NotificationPlanner.Action], panel: String, tile: Tile) {
        for action in actions {
            switch action {
            case .deliver(let notification): deliver(notification, panel: panel, tile: tile)
            case .withdraw(let id): withdraw([id], panel: panel)
            }
        }
    }

    private func deliver(_ notification: PanelNotification, panel: String, tile: Tile) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.subtitle = notification.subtitle ?? ""
        content.body = notification.body ?? ""
        content.threadIdentifier = panel
        content.sound = (tile.notify?.sound ?? settings.sound) ? .default : nil
        content.userInfo = ["panel": panel, "url": notification.url ?? "", "command": notification.command ?? ""]
        add(UNNotificationRequest(identifier: "\(panel)/\(notification.id)", content: content, trigger: nil))
    }

    private func withdraw(_ ids: [String], panel: String) {
        guard !ids.isEmpty else { return }
        center?.removeDeliveredNotifications(withIdentifiers: ids.map { "\(panel)/\($0)" })
    }

    /// Adds a request once Tjuvkik may notify. The first one asks macOS, once.
    private func add(_ request: UNNotificationRequest) {
        guard let center else { return }
        switch permission {
        case .granted: center.add(request)
        case .denied: break
        case .unknown:
            held.append(request)
            if held.count > 20 { held.removeFirst() }
            askPermission()
        }
    }

    private func askPermission() {
        guard let center, !requesting else { return }
        requesting = true
        center.requestAuthorization(options: [.alert, .sound]) { @Sendable granted, _ in
            Task { @MainActor [weak self] in self?.answered(granted) }
        }
    }

    private func answered(_ granted: Bool) {
        permission = granted ? .granted : .denied
        requesting = false
        if granted { for request in held { center?.add(request) } }
        held.removeAll()
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let panel = info["panel"] as? String ?? ""
        let url = info["url"] as? String ?? ""
        let command = info["command"] as? String ?? ""
        Task { @MainActor [weak self] in
            if !command.isEmpty {
                self?.onCommand(command, panel)
            } else if !url.isEmpty, let link = URL(string: url) {
                NSWorkspace.shared.open(link)
            }
        }
        completionHandler()
    }
}
