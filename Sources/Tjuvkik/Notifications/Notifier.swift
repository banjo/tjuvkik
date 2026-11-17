import AppKit
import TjuvkikCore
@preconcurrency import UserNotifications

/// Delivers panels' notifications through Notification Center, and handles clicks on them.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    enum Permission { case unknown, granted, denied }

    private(set) var permission = Permission.unknown {
        didSet { if permission != oldValue { onPermissionChange(permission) } }
    }
    var onPermissionChange: (Permission) -> Void = { _ in }
    /// Runs a clicked notification's command: `(command, tile id)`.
    var onCommand: (String, String) -> Void = { _, _ in }

    private let center: UNUserNotificationCenter?
    // Per tile, by id, replaced on each update and removed with the tile.
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

    /// Forgets the tiles that no longer run, and withdraws what they delivered.
    func keep(_ ids: Set<String>) {
        for id in Set(planners.keys).union(tiles.keys).union(signatures.keys) where !ids.contains(id) {
            forget(id)
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

    /// Called when a tile's content or error changes.
    func update(id: String, tile: Tile, state: PanelStore.State, config: Config, glanceOpen: Bool) {
        settings = config.notifications
        guard config.notifications.enabled, let notify = tile.notify else {
            forget(id)
            return
        }
        let signature = "\(tile.command)|\(tile.directory.path)"
        if signatures[id] != signature {
            withdraw(planners[id]?.deliveredIDs ?? [], from: id)
            planners[id] = NotificationPlanner()
            signatures[id] = signature
        }
        tiles[id] = tile

        let wanted = PanelNotifications.collect(content: state.content, error: state.error, title: tile.title, on: notify.on)
        let muted = (config.notifications.quietHours?.contains(Date()) ?? false) || (glanceOpen && !config.notifications.whileOpen)
        guard var planner = planners[id] else { return }
        let actions = planner.update(wanted, now: Date(), muted: muted, minInterval: notify.minInterval, panelTitle: tile.title)
        planners[id] = planner
        perform(actions, id: id, tile: tile)
    }

    private func flushAll() {
        let now = Date()
        for (id, var planner) in planners {
            guard let tile = tiles[id], let notify = tile.notify else { continue }
            let actions = planner.flush(now: now, minInterval: notify.minInterval, panelTitle: tile.title)
            guard !actions.isEmpty else { continue }
            planners[id] = planner
            perform(actions, id: id, tile: tile)
        }
    }

    private func forget(_ id: String) {
        withdraw(planners[id]?.deliveredIDs ?? [], from: id)
        planners[id] = nil
        signatures[id] = nil
        tiles[id] = nil
    }

    // MARK: Delivering

    private func perform(_ actions: [NotificationPlanner.Action], id: String, tile: Tile) {
        for action in actions {
            switch action {
            case .deliver(let notification): deliver(notification, id: id, tile: tile)
            case .withdraw(let notification): withdraw([notification], from: id)
            }
        }
    }

    private func deliver(_ notification: PanelNotification, id: String, tile: Tile) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.subtitle = notification.subtitle ?? ""
        content.body = notification.body ?? ""
        content.threadIdentifier = id
        content.sound = (tile.notify?.sound ?? settings.sound) ? .default : nil
        content.userInfo = ["id": id, "url": notification.url ?? "", "command": notification.command ?? ""]
        add(UNNotificationRequest(identifier: "\(id)/\(notification.id)", content: content, trigger: nil))
    }

    private func withdraw(_ ids: [String], from id: String) {
        guard !ids.isEmpty else { return }
        center?.removeDeliveredNotifications(withIdentifiers: ids.map { "\(id)/\($0)" })
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
        let id = info["id"] as? String ?? ""
        let url = info["url"] as? String ?? ""
        let command = info["command"] as? String ?? ""
        Task { @MainActor [weak self] in
            if !command.isEmpty {
                self?.onCommand(command, id)
            } else if !url.isEmpty, let link = URL(string: url) {
                NSWorkspace.shared.open(link)
            }
        }
        completionHandler()
    }
}
