import Foundation

/// Loads the config directory:
///
///     config.jsonc               theme, trigger, and which panels go where
///     panels/<name>/panel.jsonc  what a panel is; its commands run in its folder
///     themes/<name>.jsonc        custom themes
///
/// Each file can also end in `.json`.
///
/// Errors fail the load; warnings (like a value from a later version) fall back to the default.
public enum ConfigLoader {
    public static let minimumInterval: Double = 5

    public static func load(from directory: URL) -> Result<LoadedConfig, ConfigErrors> {
        var files = ConfigFiles(directory: directory)
        let file = files.locate(ConfigFiles.config)
        guard let raw = files.read(RawConfig.self, from: file) else { return .failure(ConfigErrors(issues: files.issues)) }

        var view = Config.View.bento
        if let value = raw.view {
            switch Config.View(rawValue: value) {
            case .bento: break
            case .spotlight: files.warning(file, "view", "\"spotlight\" isn't available yet, using \"bento\"")
            case nil: files.error(file, "view", "unknown view \"\(value)\", expected \"bento\" or \"spotlight\"")
            }
            view = .bento
        }

        var layout = Config.Layout.framed
        if let value = raw.layout {
            switch Config.Layout(rawValue: value) {
            case .framed: break
            case .fullscreen, .edges: files.warning(file, "layout", "\"\(value)\" isn't available yet, using \"framed\"")
            case nil: files.error(file, "layout", "unknown layout \"\(value)\", expected \"framed\", \"fullscreen\" or \"edges\"")
            }
            layout = .framed
        }

        let themeName = raw.theme ?? "dark-glass"
        var resolver = ThemeResolver(files: files)
        let theme = resolver.resolve(themeName, from: file)
        files = resolver.files

        var hold = 250
        if let value = raw.trigger?.holdMs {
            if (50...2000).contains(value) { hold = value } else {
                files.error(file, "trigger.holdMs", "must be between 50 and 2000, got \(value)")
            }
        }

        let refs = raw.panels ?? []
        var tiles = refs.enumerated().compactMap { index, ref in
            tile(ref, path: "panels[\(index)]", config: file, files: &files)
        }
        let slots = BentoPacking.pack(tiles.map(\.size))
        for index in tiles.indices {
            tiles[index].slot = slots[index]
            if slots[index] == nil {
                files.warning(file, "panels[\(index)]", "\"\(tiles[index].panel)\" doesn't fit on the 4×3 grid and is left out")
            }
        }

        if let name = raw.menuBar {
            if !refs.contains(where: { $0.panel == name }) {
                files.error(file, "menuBar", "\"\(name)\" isn't in panels")
            } else if let tile = tiles.first(where: { $0.panel == name }), tile.slot == nil {
                files.warning(file, "menuBar", "\"\(name)\" doesn't fit on the grid, so it doesn't run")
            }
        }

        let errors = files.issues.filter { $0.severity == .error }
        guard errors.isEmpty, let theme else { return .failure(ConfigErrors(issues: errors)) }
        let config = Config(
            view: view, layout: layout, themeName: themeName, theme: theme,
            holdMilliseconds: hold, launchAtLogin: raw.launchAtLogin ?? true, tiles: tiles, menuBar: raw.menuBar
        )
        return .success(LoadedConfig(config: config, warnings: files.issues))
    }

    /// Resolves a `panels` entry to its panel. The size here wins over the panel's own.
    private static func tile(_ ref: RawPanelRef, path: String, config: String, files: inout ConfigFiles) -> Tile? {
        guard let name = ref.panel, !name.isEmpty else {
            files.error(config, path, "missing \"panel\"")
            return nil
        }
        let start = files.issues.count
        var refSize: TileSize?
        if let value = ref.size {
            refSize = TileSize(rawValue: value)
            if refSize == nil { files.error(config, "\(path).size", sizeMessage(value)) }
        }

        guard !name.contains("/"), !name.hasPrefix(".") else {
            files.error(config, "\(path).panel", "\"\(name)\" isn't a panel name")
            return nil
        }
        guard files.exists(ConfigFiles.panel(name)) else {
            files.error(config, "\(path).panel", "no panel \"\(name)\": create \(ConfigFiles.panel(name)).jsonc")
            return nil
        }
        let file = files.locate(ConfigFiles.panel(name))
        guard let raw = files.read(RawPanel.self, from: file) else { return nil }

        let kinds = Tile.Kind.allCases.map { "\"\($0.rawValue)\"" }.joined(separator: " or ")
        var kind: Tile.Kind?
        switch raw.type {
        case let type?:
            kind = Tile.Kind(rawValue: type)
            if kind == nil { files.error(file, "type", "unknown type \"\(type)\", expected \(kinds)") }
        case nil:
            files.error(file, "type", "missing \"type\", expected \(kinds)")
        }

        var mode = Tile.Mode.interval
        if let value = raw.mode {
            if let parsed = Tile.Mode(rawValue: value) { mode = parsed } else {
                files.error(file, "mode", "unknown mode \"\(value)\", expected \"interval\" or \"stream\"")
            }
        }

        let command = raw.command?.trimmingCharacters(in: .whitespaces) ?? ""
        if command.isEmpty, let kind { files.error(file, "command", "a \(kind.rawValue) panel needs a command") }

        var panelSize = TileSize.s
        if let value = raw.size {
            if let size = TileSize(rawValue: value) { panelSize = size } else { files.error(file, "size", sizeMessage(value)) }
        }
        let every = interval(raw.every, default: 60, minimum: minimumInterval, file: file, path: "every", files: &files)
        let timeout = interval(raw.timeout, default: 10, minimum: 0.1, file: file, path: "timeout", files: &files)

        let requires = raw.requires ?? []
        for (index, tool) in requires.enumerated() where tool.isEmpty || tool.contains("/") {
            files.error(file, "requires[\(index)]", "\"\(tool)\" isn't a command name")
        }

        guard files.issues.count == start, let kind, let every, let timeout else { return nil }
        return Tile(
            panel: name, kind: kind, mode: mode, command: command, title: raw.title ?? name,
            size: refSize ?? panelSize, every: every, timeout: timeout, requires: requires,
            directory: files.directory.appending(path: "panels/\(name)")
        )
    }

    private static func sizeMessage(_ value: String) -> String {
        "unknown size \"\(value)\", expected \"s\", \"m\", \"l\" or \"xl\""
    }

    private static func interval(_ text: String?, default value: Double, minimum: Double, file: String, path: String, files: inout ConfigFiles) -> Double? {
        guard let text else { return value }
        guard let seconds = Interval.seconds(text) else {
            files.error(file, path, "can't read \"\(text)\", write it like \"30s\", \"5m\" or \"1h\"")
            return nil
        }
        guard seconds >= minimum else {
            files.error(file, path, "must be at least \(minimum.secondsText)s, got \"\(text)\"")
            return nil
        }
        return seconds
    }
}
