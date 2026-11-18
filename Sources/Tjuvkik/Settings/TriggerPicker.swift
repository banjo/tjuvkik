import AppKit
import SwiftUI
import TjuvkikCore

/// Picks what opens the glance: a key or a shortcut, how it's used, and its timing.
struct TriggerPicker: View {
    let trigger: Trigger
    let onChange: (Trigger) -> Void

    private enum Kind: Hashable { case key, shortcut }

    /// Shortcut is picked, but none recorded yet.
    @State private var wantsShortcut = false
    @State private var hold = 250.0
    @State private var doubleTap = 300.0

    var body: some View {
        Picker("Trigger", selection: kind) {
            Text("Key").tag(Kind.key)
            Text("Shortcut").tag(Kind.shortcut)
        }
        .pickerStyle(.segmented)

        switch trigger.input {
        case .key(let key) where !wantsShortcut:
            Picker("Key", selection: Binding(get: { key }, set: { key in changed { $0.input = .key(key) } })) {
                ForEach(Trigger.Key.allCases, id: \.self) { Text($0.name).tag($0) }
            }
        default:
            LabeledContent("Shortcut") {
                ShortcutRecorder(shortcut: shortcut) { recorded in
                    wantsShortcut = false
                    var new = trigger
                    if case .key = trigger.input { new.mode = .toggle }
                    new.input = .shortcut(recorded)
                    onChange(new)
                }
            }
        }

        Picker("Mode", selection: Binding(get: { trigger.mode }, set: { mode in changed { $0.mode = mode } })) {
            Text("Hold").tag(Trigger.Mode.hold)
            Text("Toggle").tag(Trigger.Mode.toggle)
            if case .key = trigger.input, !wantsShortcut { Text("Double Tap").tag(Trigger.Mode.doubleTap) }
        }
        .pickerStyle(.segmented)
        .disabled(wantsShortcut)

        if trigger.mode == .hold, !wantsShortcut {
            LabeledContent("Hold time") {
                HStack {
                    Slider(value: $hold, in: 50...2000, step: 10) { editing in
                        if !editing { changed { $0.holdMilliseconds = Int(hold) } }
                    }
                    Text("\(Int(hold)) ms").monospacedDigit().frame(width: 64, alignment: .trailing)
                }
            }
            .onAppear { hold = Double(trigger.holdMilliseconds) }
            .onChange(of: trigger.holdMilliseconds) { hold = Double(trigger.holdMilliseconds) }
        }
        if trigger.mode == .doubleTap, !wantsShortcut {
            LabeledContent("Double-tap time") {
                HStack {
                    Slider(value: $doubleTap, in: 150...600, step: 10) { editing in
                        if !editing { changed { $0.doubleTapMilliseconds = Int(doubleTap) } }
                    }
                    Text("\(Int(doubleTap)) ms").monospacedDigit().frame(width: 64, alignment: .trailing)
                }
            }
            .onAppear { doubleTap = Double(trigger.doubleTapMilliseconds) }
            .onChange(of: trigger.doubleTapMilliseconds) { doubleTap = Double(trigger.doubleTapMilliseconds) }
        }

        Toggle("Close on click outside", isOn: Binding(get: { trigger.closeOnClickOutside }, set: { on in changed { $0.closeOnClickOutside = on } }))
    }

    private var shortcut: Shortcut? {
        if case .shortcut(let shortcut) = trigger.input { shortcut } else { nil }
    }

    private var kind: Binding<Kind> {
        Binding {
            shortcut != nil || wantsShortcut ? .shortcut : .key
        } set: { kind in
            switch kind {
            case .key:
                wantsShortcut = false
                if shortcut != nil { onChange(Trigger(input: .key(.fn), mode: .hold, closeOnClickOutside: trigger.closeOnClickOutside)) }
            case .shortcut:
                if shortcut == nil { wantsShortcut = true }
            }
        }
    }

    private func changed(_ change: (inout Trigger) -> Void) {
        var new = trigger
        change(&new)
        if new != trigger { onChange(new) }
    }
}

/// A button that records the next shortcut typed: a key with ⌃, ⌥ or ⌘, or an F-key. Esc cancels.
struct ShortcutRecorder: View {
    let shortcut: Shortcut?
    let onRecord: (Shortcut) -> Void

    @State private var monitor: Any?
    @State private var message: String?
    @State private var messageCount = 0

    var body: some View {
        HStack {
            if let message {
                Text(message).foregroundStyle(.red)
            }
            Button(monitor != nil ? "Type a Shortcut…" : shortcut?.description ?? "Record Shortcut") {
                if monitor == nil { start() } else { stop() }
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        stop()
        // Local monitors are called on the main thread.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { record(event) }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func record(_ event: NSEvent) {
        if event.keyCode == 53 {
            stop()
            return
        }
        guard let name = Shortcut.name(forKeyCode: UInt32(event.keyCode)) else {
            show("That key can't be used")
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let symbols: [(NSEvent.ModifierFlags, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        let modifiers = symbols.filter { flags.contains($0.0) }.map(\.1).joined()
        let isFunctionKey = name.hasPrefix("F") && name.count > 1
        guard isFunctionKey || flags.contains(.control) || flags.contains(.option) || flags.contains(.command) else { return }
        guard case .success(let shortcut) = Shortcut.parse(modifiers + name) else {
            show("That key can't be used")
            return
        }
        stop()
        onRecord(shortcut)
    }

    private func show(_ text: String) {
        messageCount += 1
        let count = messageCount
        message = text
        Task {
            try? await Task.sleep(for: .seconds(2))
            if messageCount == count { message = nil }
        }
    }
}
