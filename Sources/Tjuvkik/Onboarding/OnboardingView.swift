import AppKit
import SwiftUI
import TjuvkikCore

/// Four steps, each editing config.jsonc as the settings window does. Skip goes on without
/// writing anything.
struct OnboardingView: View {
    let model: SettingsModel
    /// True the first time it's called on first start.
    let tickStarters: () -> Bool
    /// Closes the window; `true` after Done.
    let close: (Bool) -> Void

    @State private var step = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let steps = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Step \(step) of \(Self.steps)").font(.callout).foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(1...Self.steps, id: \.self) { index in
                        Circle()
                            .fill(index <= step ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .padding(.bottom, 8)

            SettingsBanner(model: model)

            ZStack {
                Group {
                    switch step {
                    case 1: TriggerStep(model: model)
                    case 2: PanelsStep(model: model, tickStarters: tickStarters)
                    case 3: ThemeStep(model: model)
                    default: DoneStep(model: model)
                    }
                }
                .id(step)
                .transition(reduceMotion ? .opacity : .push(from: .trailing))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(.easeOut(duration: 0.2), value: step)
            .disabled(model.parseError != nil)

            Divider()
            HStack {
                if step > 1 {
                    Button("Back") { step -= 1 }
                }
                Spacer()
                Button("Skip") { next(done: false) }
                Button(step == Self.steps ? "Done" : "Continue") { next(done: true) }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
        .onChange(of: model.store.revision) { model.reload() }
    }

    private func next(done: Bool) {
        if step < Self.steps { step += 1 } else { close(done) }
    }
}

private struct StepTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.bold())
            Text(subtitle).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }
}

// MARK: Step 1

private struct TriggerStep: View {
    let model: SettingsModel

    var body: some View {
        let trigger = model.store.config.trigger
        VStack(spacing: 0) {
            StepTitle(title: "Hold a key, see everything", subtitle: "Tjuvkik shows your panels for as long as you hold a key, then gets out of the way.")
            Form {
                Section {
                    TriggerPicker(trigger: trigger) { new in model.change { try $0.setTrigger(new) } }
                }
                Section {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(alignment: .leading, spacing: 8) {
                            if case .key(let key) = trigger.input, !InputMonitoring.isGranted {
                                HStack {
                                    Text("Tjuvkik needs Input Monitoring to see \(key == .fn ? "the fn key" : key.name)")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Allow Input Monitoring…") { InputMonitoring.openSettings() }
                                }
                            }
                            if case .key(.fn) = trigger.input {
                                HStack {
                                    Text("If fn opens emoji or starts dictation, set “Press 🌐 key to” to “Do nothing”")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Open Keyboard Settings…") {
                                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
                                    }
                                }
                            }
                            HStack {
                                Text("Try it: \(trigger.instruction)")
                                Spacer()
                                if let last = model.lastTriggered, context.date.timeIntervalSince(last) < 3 {
                                    Label("Works", systemImage: "checkmark").foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}

// MARK: Step 2

private struct PanelsStep: View {
    let model: SettingsModel
    let tickStarters: () -> Bool

    @State private var starters: [Starter] = []
    @Environment(\.colorScheme) private var colorScheme

    /// Ticked the first time the step opens on first start, when they can run.
    private static let tickedAtStart = ["cpu-memory", "battery", "github"]

    var body: some View {
        let config = model.store.config
        let entries = model.entries
        VStack(spacing: 0) {
            StepTitle(title: "Pick your panels", subtitle: "Each is a folder in panels/ that you can change. Add more later.")
            HStack(alignment: .top, spacing: 16) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(starters) { starter in
                            StarterToggle(starter: starter, isOn: Binding(
                                get: { entries.contains { $0.panel == starter.name } },
                                set: { on in set(starter, on: on) }
                            ))
                        }
                    }
                    .padding(.vertical, 12)
                }
                .frame(width: 270)

                VStack(alignment: .leading, spacing: 8) {
                    BoardMiniature(config: config, theme: config.theme(dark: colorScheme == .dark), states: model.panels.states)
                    let unplaced = config.tiles.filter { $0.show && $0.slot == nil }.count
                    if unplaced > 0 {
                        Text("\(unplaced == 1 ? "1 panel doesn't" : "\(unplaced) panels don't") fit. Untick some, or change sizes later in Settings.")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 24)
        }
        .onAppear(perform: load)
    }

    private func load() {
        let directory = model.store.directory
        var list: [Starter] = []
        if ConfigLoader.panelNames(in: directory).contains("disk"), case .success(let tile) = ConfigLoader.panel("disk", in: directory) {
            list.append(Starter(name: "disk", tile: tile, missing: []))
        }
        let path = model.panels.loginPath ?? ProcessInfo.processInfo.environment["PATH"] ?? ""
        starters = list + Starters.all(path: path)
        guard tickStarters() else { return }
        for starter in starters where Self.tickedAtStart.contains(starter.name) && starter.missing.isEmpty {
            if !model.entries.contains(where: { $0.panel == starter.name }) { model.addStarter(starter) }
        }
    }

    private func set(_ starter: Starter, on: Bool) {
        if on {
            if starter.name == "disk" {
                model.change { try $0.addTile(panel: starter.name) }
            } else {
                model.addStarter(starter)
            }
        } else if let entry = model.entries.first(where: { $0.panel == starter.name }) {
            model.change { try $0.removeTile(at: entry.index) }
        }
    }
}

private struct StarterToggle: View {
    let starter: Starter
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(starter.tile.title).fontWeight(.medium)
                    if starter.isDemo {
                        Text("Sample data")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }
                }
                if let description = starter.tile.description {
                    Text(description).font(.callout).foregroundStyle(.secondary)
                }
                if !starter.missing.isEmpty {
                    Text("needs \(starter.missing.joined(separator: ", "))").font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .disabled(!starter.missing.isEmpty)
    }
}

// MARK: Step 3

private struct ThemeStep: View {
    let model: SettingsModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        _ = model.store.revision
        let config = model.store.config
        return VStack(spacing: 0) {
            StepTitle(title: "Pick a theme", subtitle: "It colors the glance and every panel on it.")
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ThemeGrid(model: model, themes: ThemePage.themes(in: model.store.directory), selected: config.themeName(dark: colorScheme == .dark)) { name in
                        model.change { try $0.setTheme(name) }
                    }
                    Text("You can pick one for light mode and one for dark later, in Settings.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
    }
}

// MARK: Step 4

private struct DoneStep: View {
    let model: SettingsModel

    var body: some View {
        let config = model.store.config
        let notifications = config.notifications
        // `background` only applies to shown interval panels that run a command.
        let runnable = config.tiles.filter { $0.mode == .interval && $0.file == nil && $0.show }
        VStack(spacing: 0) {
            StepTitle(title: "You're set", subtitle: "A few last switches.")
            Form {
                Section {
                    Toggle("Open Tjuvkik when you log in", isOn: Binding(
                        get: { config.launchAtLogin },
                        set: { on in model.change { try $0.setLaunchAtLogin(on) } }
                    ))
                    Toggle("Keep panels up to date while the glance is closed", isOn: Binding(
                        get: { runnable.isEmpty || runnable.contains { $0.background != .off } },
                        set: { on in
                            let ids = Set(runnable.map(\.id))
                            model.change { editor in
                                for entry in editor.entries() where on || ids.contains(entry.resolvedID) {
                                    try editor.setTile(entry.index, .background, on ? nil : .bool(false))
                                }
                            }
                        }
                    ))
                    Toggle("Let panels send notifications", isOn: Binding(
                        get: { notifications.enabled },
                        set: { on in
                            model.change {
                                try $0.setNotifications(enabled: on, sound: notifications.sound, quietHours: notifications.quietHoursText, whileOpen: notifications.whileOpen)
                            }
                        }
                    ))
                } footer: {
                    let path = (model.store.configFile.path as NSString).abbreviatingWithTildeInPath
                    Text("Everything here, and more, is in Settings (⌘,). Or edit \(path).")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .formStyle(.grouped)
        }
    }
}
