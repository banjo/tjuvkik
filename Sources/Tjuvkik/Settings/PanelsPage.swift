import SwiftUI
import TjuvkikCore

/// Every folder in panels/: what it is, what it needs, and what it last showed.
struct PanelsPage: View {
    let model: SettingsModel
    @State private var selection: String?

    var body: some View {
        _ = model.store.revision
        let directory = model.store.directory
        let panels = ConfigLoader.panelNames(in: directory).map { (name: $0, result: ConfigLoader.panel($0, in: directory)) }
        return HStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(panels, id: \.name) { panel in
                    VStack(alignment: .leading, spacing: 1) {
                        switch panel.result {
                        case .success(let tile):
                            Text(tile.title).lineLimit(1)
                            Text(panel.name == tile.title ? tile.typeName : "\(panel.name) · \(tile.typeName)")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        case .failure:
                            Text(panel.name).lineLimit(1)
                            Text("has errors").font(.caption).foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 2)
                    .tag(panel.name)
                }
            }
            .frame(width: 260)

            Divider()

            if let selected = panels.first(where: { $0.name == selection }) {
                PanelDetail(model: model, name: selected.name, result: selected.result)
            } else {
                Text(panels.isEmpty ? "No panels yet. Make one with tjuvkik new." : "Select a panel.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct PanelDetail: View {
    let model: SettingsModel
    let name: String
    let result: Result<Tile, ConfigErrors>

    var body: some View {
        let file = SettingsFiles.panelFile(name, in: model.store.directory)
        Form {
            switch result {
            case .success(let panel):
                Section(panel.title) {
                    LabeledContent("Type", value: panel.typeName)
                    LabeledContent("Runs", value: panel.mode == .stream ? "live" : panel.file != nil ? "when its file changes" : "every \(Self.duration(panel.every))")
                    if let description = panel.description, !description.isEmpty { LabeledContent("Description", value: description) }
                    if let author = panel.author { LabeledContent("Author", value: author) }
                    if let version = panel.version { LabeledContent("Version", value: version) }
                }
                if !panel.requires.isEmpty {
                    Section("Needs") {
                        let missing = model.panels.missingTools(panel)
                        ForEach(panel.requires, id: \.self) { tool in
                            LabeledContent(tool) {
                                if let missing {
                                    if missing.contains(tool) {
                                        Text("\(tool) not found on PATH").foregroundStyle(.red)
                                    } else {
                                        Image(systemName: "checkmark").foregroundStyle(.green)
                                    }
                                } else {
                                    Text("Checking…").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                if !panel.declaredOptions.isEmpty {
                    Section("Options") {
                        ForEach(panel.declaredOptions, id: \.name) { option in
                            LabeledContent(option.title ?? option.name) {
                                Text(Self.summary(option)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("On the board") {
                    let ids = model.entries.filter { $0.panel == name }.map(\.resolvedID)
                    if ids.isEmpty {
                        HStack {
                            Text("Not on the board").foregroundStyle(.secondary)
                            Spacer()
                            Button("Add to Board") { model.change { try $0.addTile(panel: name) } }
                        }
                    } else {
                        Text(ids.joined(separator: ", "))
                    }
                }
                LastOutput(model: model, name: name)
            case .failure(let failure):
                Section("Errors") {
                    ForEach(Array(failure.issues.enumerated()), id: \.offset) { _, issue in
                        Text(issue.description).foregroundStyle(.red).textSelection(.enabled)
                    }
                }
            }
            Section {
                HStack {
                    Spacer()
                    Button("Open in Editor") { SettingsFiles.open(file) }
                    Button("Show in Finder") { SettingsFiles.reveal(file) }
                }
            }
        }
        .formStyle(.grouped)
    }

    /// "string, default \"main\", required".
    private static func summary(_ option: PanelOption) -> String {
        var parts = [option.choices.map { $0.joined(separator: " | ") } ?? option.kind.rawValue]
        if let value = option.defaultValue { parts.append("default \(value.text)") }
        if option.required { parts.append("required") }
        return parts.joined(separator: ", ")
    }

    static func duration(_ seconds: Double) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.days, .hours, .minutes, .seconds], width: .narrow))
    }
}

/// Each board tile of a panel as it last drew, with its error and when it updated.
private struct LastOutput: View {
    let model: SettingsModel
    let name: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let config = model.store.config
        let theme = config.theme(dark: colorScheme == .dark)
        let tiles = config.tiles.filter { $0.panel == name && ($0.slot != nil || !$0.show) }
        if !tiles.isEmpty {
            Section("Last output") {
                ForEach(tiles, id: \.id) { tile in
                    let state = model.panels.states[tile.id]
                    VStack(alignment: .leading, spacing: 6) {
                        if tiles.count > 1 { Text(tile.id).font(.caption).foregroundStyle(.secondary) }
                        ScaledTile(tile: tile, state: state, theme: theme, width: 420)
                        if let error = state?.error {
                            Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                        }
                        Text(state?.updated.map { "Updated \($0.formatted(.relative(presentation: .named)))" } ?? "Not updated yet")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// A tile at its size on the full board, shrunk to fit `width`.
struct ScaledTile: View {
    let tile: Tile
    let state: PanelStore.State?
    let theme: Theme
    let width: CGFloat

    var body: some View {
        let size = BentoGeometry.size(of: tile.size, board: theme.board)
        let scale = min(1, width / size.width)
        TileView(tile: tile, state: state, theme: theme, index: 0, isVisible: true, solid: true)
            .frame(width: size.width, height: size.height)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
            .environment(\.colorScheme, theme.appearance.colorScheme)
    }
}
