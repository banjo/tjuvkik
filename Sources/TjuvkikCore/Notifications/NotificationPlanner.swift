import Foundation

/// Decides, for one panel, which notifications to deliver and withdraw as its output changes.
public struct NotificationPlanner: Sendable {
    public enum Action: Equatable, Sendable {
        case deliver(PanelNotification)
        case withdraw(id: String)
    }

    /// Ids in the last output, delivered or not.
    private var seen: Set<String> = []
    /// Ids that were delivered and can be withdrawn.
    private var delivered: Set<String> = []
    /// New ones held back by `minInterval`, oldest first.
    private var waiting: [PanelNotification] = []
    private var lastDelivered: Date?
    private var started = false
    private var groups = 0

    public init() {}

    /// Takes the panel's current notifications. `muted`: quiet hours, or the glance is open.
    public mutating func update(_ notifications: [PanelNotification], now: Date, muted: Bool, minInterval: Double, panelTitle: String) -> [Action] {
        let ids = Set(notifications.map(\.id))
        var withdrawals: [Action] = []
        for id in seen.sorted() where !ids.contains(id) {
            waiting.removeAll { $0.id == id }
            if delivered.remove(id) != nil { withdrawals.append(.withdraw(id: id)) }
        }
        guard started else {
            seen = ids
            started = true
            return withdrawals
        }

        var deliveries: [Action] = []
        for notification in notifications where !seen.contains(notification.id) {
            if muted { continue }
            let due = minInterval == 0 || lastDelivered.map { now.timeIntervalSince($0) >= minInterval } ?? true
            if (minInterval == 0 || deliveries.isEmpty) && due && waiting.isEmpty {
                deliveries.append(.deliver(notification))
                delivered.insert(notification.id)
                lastDelivered = now
            } else {
                waiting.append(notification)
                if waiting.count > Self.waitingLimit { waiting.removeFirst() }
            }
        }
        seen = ids
        return withdrawals + deliveries
    }

    /// Sends what `minInterval` held back once it has passed. Called every second.
    public mutating func flush(now: Date, minInterval: Double, panelTitle: String) -> [Action] {
        guard !waiting.isEmpty, lastDelivered.map({ now.timeIntervalSince($0) >= minInterval }) ?? true else { return [] }
        let action: Action
        if waiting.count == 1 {
            action = .deliver(waiting[0])
            delivered.insert(waiting[0].id)
        } else {
            groups += 1
            action = .deliver(PanelNotification(
                id: "tjuvkik:group:\(groups)", title: panelTitle,
                body: "\(waiting.count) new: " + waiting.map(\.title).joined(separator: ", ")
            ))
        }
        waiting.removeAll()
        lastDelivered = now
        return [action]
    }

    /// What's in Notification Center now, so it can be withdrawn when the panel is turned off or removed.
    public var deliveredIDs: [String] { delivered.sorted() }

    /// The most notifications `waiting` holds. When it's full, the oldest is dropped.
    public static let waitingLimit = 50
}
