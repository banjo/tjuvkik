import SwiftUI
import TjuvkikCore

/// The tiles in order, a miniature of how they pack, and the selected tile's settings.
struct BoardPage: View {
    let model: SettingsModel
    /// The selected tile's id.
    @State private var selection: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let config = model.store.config
        let entries = model.entries
        let selected = entries.first { $0.resolvedID == selection }
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(entries, id: \.index) { entry in
                        BoardRow(entry: entry, tile: tile(entry), inMenuBar: config.menuBar.contains(entry.resolvedID), problems: problems(entry))
                            .tag(entry.resolvedID)
                    }
                    .onMove { source, destination in move(source, destination, in: entries) }
                }
                Divider()
                HStack(spacing: 2) {
                    Menu {
                        ForEach(ConfigLoader.panelNames(in: model.store.directory), id: \.self) { name in
                            Button(name) {
                                model.change { try $0.addTile(panel: name) }
                                selection = model.entries.last?.resolvedID
                            }
                        }
                    } label: {
                        Image(systemName: "plus").frame(width: 20, height: 16)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Add a panel from panels/")
                    Button {
                        guard let selected else { return }
                        model.change { try $0.removeTile(at: selected.index) }
                        selection = nil
                    } label: {
                        Image(systemName: "minus").frame(width: 20, height: 16)
                    }
                    .buttonStyle(.borderless)
                    .disabled(selected == nil)
                    .help("Remove the selected tile")
                    Spacer()
                }
                .padding(8)
            }
            .frame(width: 300)

            Divider()

            Form {
                Section {
                    BoardMiniature(
                        config: config, theme: config.theme(dark: colorScheme == .dark), states: model.panels.states,
                        selected: selection, onSelect: { selection = $0 }
                    )
                    let left = config.tiles.filter { $0.show && $0.slot == nil }
                    if !left.isEmpty {
                        Label("Doesn't fit: \(left.map(\.title).joined(separator: ", "))", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                if let selected, let editor = model.editor {
                    TileForm(model: model, entry: selected, tile: tile(selected), document: editor.document) { selection = $0 }
                        .id("\(selected.index)|\(selected.resolvedID)|\(editor.text.hashValue)")
                } else {
                    Section {
                        Text("Select a tile to change it, or drag tiles to reorder them.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    private func tile(_ entry: ConfigEditor.Entry) -> Tile? {
        model.store.config.tiles.first { $0.id == entry.resolvedID && $0.panel == entry.panel }
    }

    /// Issues at the entry's path in config.jsonc, or that it doesn't fit.
    private func problems(_ entry: ConfigEditor.Entry) -> [String] {
        let file = model.store.configFile.lastPathComponent
        var messages = (model.store.errors + model.store.warnings)
            .filter { $0.file == file && $0.path.hasPrefix("panels[\(entry.index)]") }
            .map(\.message)
        if messages.isEmpty, let tile = tile(entry), tile.show, tile.slot == nil {
            messages.append("Doesn't fit on the 4×3 grid")
        }
        return messages
    }

    /// `destination` is where it goes in the list before it moves, as SwiftUI gives it.
    private func move(_ source: IndexSet, _ destination: Int, in entries: [ConfigEditor.Entry]) {
        guard let from = source.first else { return }
        let to = destination > from ? destination - 1 : destination
        guard to != from, entries.indices.contains(to) else { return }
        model.change { try $0.moveTile(from: entries[from].index, to: entries[to].index) }
    }
}

private struct BoardRow: View {
    let entry: ConfigEditor.Entry
    let tile: Tile?
    let inMenuBar: Bool
    let problems: [String]

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(tile?.title ?? entry.panel).lineLimit(1)
                if entry.resolvedID != entry.panel {
                    Text(entry.panel).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if !problems.isEmpty {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange).help(problems.joined(separator: "\n"))
            }
            if inMenuBar {
                Image(systemName: "menubar.rectangle").foregroundStyle(.secondary).help("In the menu bar")
            }
            if let tile {
                Text(tile.size.rawValue)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.vertical, 2)
    }
}

/// The selected tile's settings: what config.jsonc says about it, each removed at its default.
private struct TileForm: View {
    let model: SettingsModel
    let entry: ConfigEditor.Entry
    let tile: Tile?
    let document: JSONCDocument
    let onRename: (String) -> Void

    /// The panel on its own, for its defaults.
    private let own: Tile?
    @State private var id: String
    @State private var idError: String?
    @State private var title: String
    @State private var every: String
    @State private var choosingEvery = false
    @State private var texts: [String: String]

    private enum BackgroundChoice: Hashable { case panel, off, every }

    init(model: SettingsModel, entry: ConfigEditor.Entry, tile: Tile?, document: JSONCDocument, onRename: @escaping (String) -> Void) {
        self.model = model
        self.entry = entry
        self.tile = tile
        self.document = document
        self.onRename = onRename
        own = try? ConfigLoader.panel(entry.panel, in: model.store.directory).get()
        let base: [JSONCDocument.Key] = ["panels", .index(entry.index)]
        _id = State(initialValue: entry.id ?? "")
        _title = State(initialValue: document.value(String.self, at: base + ["title"]) ?? "")
        _every = State(initialValue: document.value(String.self, at: base + ["background"]) ?? "")
        var texts: [String: String] = [:]
        for option in (tile ?? own)?.declaredOptions ?? [] {
            let path = base + ["options", .name(option.name)]
            texts[option.name] = document.value(String.self, at: path) ?? document.value(Double.self, at: path).map { OptionValue.number($0).text }
        }
        _texts = State(initialValue: texts)
    }

    private var base: [JSONCDocument.Key] { ["panels", .index(entry.index)] }
    private func value<T: Decodable>(_ type: T.Type, _ key: JSONCDocument.Key) -> T? { document.value(type, at: base + [key]) }

    var body: some View {
        let index = entry.index
        Section(tile?.title ?? entry.panel) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("ID", text: $id, prompt: Text(entry.panel)).onSubmit(rename)
                if let idError {
                    Text(idError).font(.caption).foregroundStyle(.red)
                }
            }
            TextField("Title", text: $title, prompt: Text(own?.title ?? entry.panel))
                .onSubmit { model.change { try $0.setTile(index, .title, title.isEmpty ? nil : .string(title)) } }
            Picker("Size", selection: Binding<String?>(
                get: { value(String.self, "size") },
                set: { size in model.change { try $0.setTile(index, .size, size.map { .string($0) }) } }
            )) {
                Text("Panel's own (\(own?.size.rawValue ?? "s"))").tag(String?.none)
                ForEach(TileSize.allCases, id: \.self) { Text($0.rawValue).tag(String?.some($0.rawValue)) }
            }
            Toggle("On the board", isOn: Binding(
                get: { value(Bool.self, "show") ?? true },
                set: { on in model.change { try $0.setTile(index, .show, on ? nil : .bool(false)) } }
            ))
            Toggle("In the menu bar", isOn: Binding(
                get: { model.store.config.menuBar.contains(entry.resolvedID) },
                set: { on in model.change { try $0.setInMenuBar(entry.resolvedID, on) } }
            ))
            Picker("Runs in the background", selection: background) {
                Text("Panel's default").tag(BackgroundChoice.panel)
                Text("Only when I glance").tag(BackgroundChoice.off)
                Text("Every…").tag(BackgroundChoice.every)
            }
            if background.wrappedValue == .every {
                TextField("Every", text: $every, prompt: Text("5m"))
                    .onSubmit {
                        guard Interval.seconds(every) != nil else { return }
                        model.change { try $0.setTile(index, .background, .string(every)) }
                    }
            }
            Toggle("Notifications", isOn: Binding(
                get: { value(Bool.self, "notify") != false },
                set: { on in model.change { try $0.setTile(index, .notify, on ? nil : .bool(false)) } }
            ))
        }

        let options = (tile ?? own)?.declaredOptions ?? []
        if !options.isEmpty {
            Section("Options") {
                ForEach(options, id: \.name) { option in
                    VStack(alignment: .leading, spacing: 4) {
                        optionField(option)
                        if let description = option.description {
                            Text(description).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        Section {
            HStack {
                Button("Run Now") { model.panels.runNow(entry.resolvedID) }
                    .disabled(tile?.mode == .stream)
                Spacer()
                Button("Open panel.jsonc") { SettingsFiles.open(SettingsFiles.panelFile(entry.panel, in: model.store.directory)) }
                Button("Show in Finder") { SettingsFiles.reveal(SettingsFiles.panelFile(entry.panel, in: model.store.directory)) }
            }
        }
    }

    private var background: Binding<BackgroundChoice> {
        Binding {
            if choosingEvery || value(String.self, "background") != nil { return .every }
            return value(Bool.self, "background") == false ? .off : .panel
        } set: { choice in
            choosingEvery = choice == .every
            switch choice {
            case .panel: model.change { try $0.setTile(entry.index, .background, nil) }
            case .off: model.change { try $0.setTile(entry.index, .background, .bool(false)) }
            case .every: break
            }
        }
    }

    private func rename() {
        let text = id.trimmingCharacters(in: .whitespaces)
        let new = text.isEmpty ? entry.panel : text
        if new != entry.panel {
            guard PanelTemplate.isValidName(new) else {
                idError = "\"\(new)\" can't be an id: use letters, digits, - and _"
                return
            }
            if let other = model.entries.first(where: { $0.index != entry.index && $0.resolvedID == new }) {
                idError = "\"\(new)\" is already used by panels[\(other.index)]"
                return
            }
        }
        idError = nil
        model.change { try $0.renameTile(entry.index, to: new) }
        onRename(new)
    }

    @ViewBuilder private func optionField(_ option: PanelOption) -> some View {
        let index = entry.index
        let path = base + ["options", .name(option.name)]
        let label = Text(option.title ?? option.name) + (option.required ? Text("  Required").font(.caption).foregroundStyle(.orange) : Text(""))
        let placeholder = option.defaultValue?.text ?? ""
        switch option.kind {
        case .string:
            if let choices = option.choices {
                Picker(selection: Binding<String?>(
                    get: { document.value(String.self, at: path) },
                    set: { choice in model.change { try $0.setOption(index, option.name, choice.map { .string($0) }) } }
                )) {
                    Text(placeholder.isEmpty ? "None" : "Default (\(placeholder))").tag(String?.none)
                    ForEach(choices, id: \.self) { Text($0).tag(String?.some($0)) }
                } label: { label }
            } else {
                TextField(text: text(option.name), prompt: Text(placeholder)) { label }
                    .onSubmit {
                        let text = texts[option.name] ?? ""
                        model.change { try $0.setOption(index, option.name, text.isEmpty ? nil : .string(text)) }
                    }
            }
        case .number:
            TextField(text: text(option.name), prompt: Text(placeholder)) { label }
                .onSubmit {
                    let text = (texts[option.name] ?? "").trimmingCharacters(in: .whitespaces)
                    if text.isEmpty {
                        model.change { try $0.setOption(index, option.name, nil) }
                    } else if let number = Double(text) {
                        model.change { try $0.setOption(index, option.name, .number(number)) }
                    }
                }
        case .boolean:
            let fallback: Bool = if case .bool(let value) = option.defaultValue { value } else { false }
            Toggle(isOn: Binding(
                get: { document.value(Bool.self, at: path) ?? fallback },
                set: { on in
                    let keep = on != fallback || (option.required && option.defaultValue == nil)
                    model.change { try $0.setOption(index, option.name, keep ? .bool(on) : nil) }
                }
            )) { label }
        }
    }

    private func text(_ name: String) -> Binding<String> {
        Binding { texts[name] ?? "" } set: { texts[name] = $0 }
    }
}
