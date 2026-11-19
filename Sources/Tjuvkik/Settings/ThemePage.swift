import SwiftUI
import TjuvkikCore

/// Picks one theme, or one for light and one for dark, from miniatures of the board.
struct ThemePage: View {
    let model: SettingsModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        _ = model.store.revision
        let config = model.store.config
        let directory = model.store.directory
        let files = ConfigLoader.themeNames(in: directory)
        let themes = Self.themes(in: directory)
        let pair = config.lightThemeName != config.darkThemeName
        let current = config.themeName(dark: colorScheme == .dark)
        return Form {
            Section {
                Picker("Themes", selection: Binding(
                    get: { pair },
                    set: { split in
                        if split {
                            let dark = config.darkThemeName == "light-glass" ? "dark-glass" : config.darkThemeName
                            model.change { try $0.setTheme(light: "light-glass", dark: dark) }
                        } else {
                            model.change { try $0.setTheme(config.darkThemeName) }
                        }
                    }
                )) {
                    Text("One theme").tag(false)
                    Text("Light and dark").tag(true)
                }
                .pickerStyle(.segmented)
            }
            if pair {
                Section("Light") {
                    ThemeGrid(model: model, themes: themes, selected: config.lightThemeName) { name in
                        model.change { try $0.setTheme(light: name, dark: config.darkThemeName) }
                    }
                }
                Section("Dark") {
                    ThemeGrid(model: model, themes: themes, selected: config.darkThemeName) { name in
                        model.change { try $0.setTheme(light: config.lightThemeName, dark: name) }
                    }
                }
            } else {
                Section {
                    ThemeGrid(model: model, themes: themes, selected: config.lightThemeName) { name in
                        model.change { try $0.setTheme(name) }
                    }
                }
            }
            Section {
                HStack {
                    Text("Make your own in themes/, see the docs.").foregroundStyle(.secondary)
                    Spacer()
                    if files.contains(current), let file = ConfigFiles.locate(ConfigFiles.theme(current), in: directory) {
                        Button("Open Theme File") { SettingsFiles.open(directory.appending(path: file)) }
                    }
                    Button("Show Themes Folder") {
                        let folder = directory.appending(path: "themes")
                        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        SettingsFiles.open(folder)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    /// The built-in themes, then the ones in themes/.
    static func themes(in directory: URL) -> [(name: String, result: Result<Theme, ConfigErrors>)] {
        let files = ConfigLoader.themeNames(in: directory)
        let names = Theme.builtIn.keys.sorted() + files.filter { Theme.builtIn[$0] == nil }
        return names.map { name in
            (name: name, result: Theme.builtIn[name].map { Result<Theme, ConfigErrors>.success($0) } ?? ConfigLoader.theme(name, in: directory))
        }
    }
}

struct ThemeGrid: View {
    let model: SettingsModel
    let themes: [(name: String, result: Result<Theme, ConfigErrors>)]
    let selected: String
    let onPick: (String) -> Void

    private var boardRatio: CGFloat {
        let board = BentoGeometry.board(model.store.config.grid, theme: .darkGlass)
        return board.width / board.height
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
            ForEach(themes, id: \.name) { theme in
                VStack(spacing: 6) {
                    switch theme.result {
                    case .success(let resolved):
                        BoardMiniature(config: model.store.config, theme: resolved, states: model.panels.states)
                    case .failure(let failure):
                        Text(failure.issues.first?.message ?? "can't be read")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(boardRatio, contentMode: .fit)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    Text(theme.name).font(.callout)
                }
                .padding(4)
                .overlay {
                    if theme.name == selected {
                        RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.accentColor, lineWidth: 3)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if case .success = theme.result { onPick(theme.name) }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
