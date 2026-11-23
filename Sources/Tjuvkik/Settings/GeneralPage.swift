import AppKit
import SwiftUI
import TjuvkikCore

/// The trigger, how the glance opens, launch at login, background runs and notifications.
struct GeneralPage: View {
    let model: SettingsModel

    var body: some View {
        let config = model.store.config
        Form {
            Section("Trigger") {
                TriggerPicker(trigger: config.trigger) { trigger in model.change { try $0.setTrigger(trigger) } }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Try it: \(config.trigger.instruction)")
                            Spacer()
                            if let last = model.lastTriggered, context.date.timeIntervalSince(last) < 3 {
                                Label("Works", systemImage: "checkmark").foregroundStyle(.green)
                            }
                        }
                        if case .key(let key) = config.trigger.input, !InputMonitoring.isGranted {
                            HStack {
                                Text("Tjuvkik needs Input Monitoring to see \(key == .fn ? "the fn key" : key.name)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Allow Input Monitoring…") { InputMonitoring.openSettings() }
                            }
                        }
                    }
                }
            }

            Section {
                Picker("Show", selection: Binding(
                    get: { config.view },
                    set: { view in model.change { try $0.setView(view) } }
                )) {
                    Text("Board").tag(Config.View.bento)
                    Text("Spotlight").tag(Config.View.spotlight)
                }
                .pickerStyle(.segmented)
                Toggle("Search in Spotlight", isOn: Binding(
                    get: { config.search },
                    set: { on in model.change { try $0.setSearch(on) } }
                ))
                .disabled(config.view != .spotlight)
            } header: {
                Text("View")
            } footer: {
                Text(config.view == .spotlight
                    ? "Every panel's rows in one list, with a tab per panel and the picked row's panel beside it. To type, Spotlight takes the keyboard from the app in front while it's open."
                    : "The panels as tiles on a grid.")
                    .foregroundStyle(.secondary)
            }

            Section("Glance") {
                Picker("Dim the screen behind it", selection: Binding(
                    get: { config.dim },
                    set: { dim in model.change { try $0.setDim(dim) } }
                )) {
                    Text("Off").tag(0.0)
                    ForEach(Self.dims(including: config.dim), id: \.self) { value in
                        Text(value == Config.defaultDim ? "A little" : value.formatted(.percent)).tag(value)
                    }
                }
                Picker("The keyboard starts on", selection: Binding(
                    get: { config.focusOnOpen },
                    set: { focus in model.change { try $0.setFocusOnOpen(focus) } }
                )) {
                    Text("The most urgent row").tag(Config.FocusOnOpen.urgent)
                    Text("The row it was on last").tag(Config.FocusOnOpen.last)
                }
                Picker("Jump between panels with", selection: Binding(
                    get: { config.jumpKey },
                    set: { key in model.change { try $0.setJumpKey(key) } }
                )) {
                    ForEach(Config.JumpKey.allCases, id: \.self) { key in
                        Text(key.symbol.map { "\($0) and the arrows" } ?? "Only Tab").tag(key)
                    }
                }
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { config.launchAtLogin },
                    set: { on in model.change { try $0.setLaunchAtLogin(on) } }
                ))
            }

            Section("Background") {
                Toggle("Pause when the screen is locked", isOn: Binding(
                    get: { config.pause.whenLocked },
                    set: { on in model.change { try $0.setPause(whenLocked: on, onLowPower: config.pause.onLowPower) } }
                ))
                Toggle("Pause on Low Power Mode", isOn: Binding(
                    get: { config.pause.onLowPower },
                    set: { on in model.change { try $0.setPause(whenLocked: config.pause.whenLocked, onLowPower: on) } }
                ))
            }

            NotificationsSection(model: model, settings: config.notifications)

            Section {
                EmptyView()
            } footer: {
                Text("Tjuvkik \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "(development)")")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
    }

    /// How dark to pick from, and the one in config.jsonc when it's another.
    private static func dims(including dim: Double) -> [Double] {
        let dims = [Config.defaultDim, 0.5, 0.7]
        return dim == 0 || dims.contains(dim) ? dims : (dims + [dim]).sorted()
    }
}

private struct NotificationsSection: View {
    let model: SettingsModel
    let settings: NotificationSettings

    var body: some View {
        Section("Notifications") {
            Toggle("Allow notifications", isOn: binding(\.enabled))
            Toggle("Play a sound", isOn: binding(\.sound))
            Toggle("Show while the glance is open", isOn: binding(\.whileOpen))
            Toggle("Quiet hours", isOn: Binding(
                get: { settings.quietHours != nil },
                set: { on in write { $0.quietHours = on ? QuietHours(start: 22 * 60, end: 7 * 60) : nil } }
            ))
            if let quiet = settings.quietHours {
                DatePicker("From", selection: time(quiet.start) { $0.start = $1 }, displayedComponents: .hourAndMinute)
                DatePicker("To", selection: time(quiet.end) { $0.end = $1 }, displayedComponents: .hourAndMinute)
            }
            if model.notificationsDenied, settings.enabled {
                HStack {
                    Text("Notifications are off for Tjuvkik").foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Notification Settings…") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                    }
                }
            }
        }
    }

    private func binding(_ key: WritableKeyPath<NotificationSettings, Bool>) -> Binding<Bool> {
        Binding(get: { settings[keyPath: key] }, set: { on in write { $0[keyPath: key] = on } })
    }

    /// A time of day, as minutes after midnight, for a DatePicker.
    private func time(_ minutes: Int, _ set: @escaping (inout QuietHours, Int) -> Void) -> Binding<Date> {
        let calendar = Calendar.current
        return Binding {
            calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
        } set: { date in
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            let new = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            write {
                guard var quiet = $0.quietHours else { return }
                set(&quiet, new)
                // Start and end can't be the same.
                if quiet.start != quiet.end { $0.quietHours = quiet }
            }
        }
    }

    private func write(_ change: (inout NotificationSettings) -> Void) {
        var new = settings
        change(&new)
        model.change { try $0.setNotifications(enabled: new.enabled, sound: new.sound, quietHours: new.quietHoursText, whileOpen: new.whileOpen) }
    }
}

extension NotificationSettings {
    /// `quietHours` as config.jsonc writes it: "22:00-07:00".
    var quietHoursText: String? {
        quietHours.map { "\(Self.clock($0.start))-\(Self.clock($0.end))" }
    }

    private static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}
