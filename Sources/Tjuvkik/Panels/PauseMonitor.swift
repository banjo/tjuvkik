import AppKit
import TjuvkikCore

/// Says when background runs pause: while the screen is locked or the displays sleep, and while
/// Low Power Mode is on, as `config.jsonc`'s `pause` allows.
@MainActor
final class PauseMonitor {
    enum Reason: String {
        case locked = "the screen is locked"
        case lowPower = "Low Power Mode is on"
    }

    /// What a notification says changed. An enum, not a closure, so the observer stays `@Sendable`.
    private enum Event: Sendable {
        case locked, unlocked, asleep, awake, power
    }

    private(set) var reason: Reason?
    var onChange: () -> Void = {}

    private var settings = Config.Pause()
    private var screenLocked = false
    private var displaysAsleep = false
    private var observers: [(center: NotificationCenter, token: any NSObjectProtocol)] = []

    func start() {
        // Observers are added once; a second start would deliver every event twice.
        guard observers.isEmpty else { return }
        // Locking comes from other processes; display sleep and the power state from this one.
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked"), .locked)
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked"), .unlocked)
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.screensDidSleepNotification, .asleep)
        observe(workspace, NSWorkspace.screensDidWakeNotification, .awake)
        observe(NotificationCenter.default, .NSProcessInfoPowerStateDidChange, .power)
        update()
    }

    func configure(_ pause: Config.Pause) {
        settings = pause
        update()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ event: Event) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.handle(event)
                self.update()
            }
        }
        observers.append((center, token))
    }

    private func handle(_ event: Event) {
        switch event {
        case .locked: screenLocked = true
        case .unlocked: screenLocked = false
        case .asleep: displaysAsleep = true
        case .awake: displaysAsleep = false
        case .power: break
        }
    }

    private func update() {
        let new: Reason? = if settings.whenLocked && (screenLocked || displaysAsleep) {
            .locked
        } else if settings.onLowPower && ProcessInfo.processInfo.isLowPowerModeEnabled {
            .lowPower
        } else {
            nil
        }
        guard new != reason else { return }
        reason = new
        onChange()
    }
}
