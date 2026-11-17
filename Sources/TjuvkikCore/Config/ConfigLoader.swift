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

        let trigger: Trigger = if let raw = raw.trigger { Self.trigger(raw, file: file, files: &files) } else { .fn }

        let refs = raw.panels ?? []
        var tiles = refs.enumerated().compactMap { index, ref in
            tile(ref, path: "panels[\(index)]", config: file, files: &files)
        }
        let shown = tiles.indices.filter { tiles[$0].show }
        let slots = BentoPacking.pack(shown.map { tiles[$0].size })
        for (position, index) in shown.enumerated() {
            tiles[index].slot = slots[position]
            if slots[position] == nil {
                files.warning(file, "panels[\(index)]", "\"\(tiles[index].panel)\" doesn't fit on the 4×3 grid and is left out")
            }
        }

        let menuBar = raw.menuBar?.values ?? []
        for (index, name) in menuBar.enumerated() {
            let path = raw.menuBar.map { $0.values.count == 1 ? "menuBar" : "menuBar[\(index)]" } ?? "menuBar"
            if !refs.contains(where: { $0.panel == name }) {
                files.error(file, path, "\"\(name)\" isn't in panels")
            } else if let tile = tiles.first(where: { $0.panel == name }), tile.show, tile.slot == nil {
                files.warning(file, path, "\"\(name)\" doesn't fit on the grid, so it doesn't run")
            }
        }

        let pause = Config.Pause(whenLocked: raw.pause?.whenLocked ?? true, onLowPower: raw.pause?.onLowPower ?? true)
        let notifications = Self.notifications(raw.notifications, file: file, files: &files)
        let errors = files.issues.filter { $0.severity == .error }
        guard errors.isEmpty, let theme else { return .failure(ConfigErrors(issues: errors)) }
        let config = Config(
            view: view, layout: layout, themeName: themeName, theme: theme,
            trigger: trigger, launchAtLogin: raw.launchAtLogin ?? true, tiles: tiles, menuBar: menuBar,
            pause: pause, notifications: notifications
        )
        return .success(LoadedConfig(config: config, warnings: files.issues))
    }

    /// One panel by its folder name, whether or not `config.jsonc` shows it. Its size is the
    /// panel's own, and it has no slot.
    public static func panel(_ name: String, in directory: URL) -> Result<Tile, ConfigErrors> {
        var files = ConfigFiles(directory: directory)
        let tile = tile(RawPanelRef(panel: name), path: "", config: "", files: &files)
        let errors = files.issues.filter { $0.severity == .error }
        guard errors.isEmpty, let tile else { return .failure(ConfigErrors(issues: errors)) }
        return .success(tile)
    }

    /// The folders in `panels/` that have a `panel.jsonc` or `panel.json`, sorted.
    public static func panelNames(in directory: URL) -> [String] {
        let panels = directory.appending(path: "panels")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: panels.path)) ?? []
        return names.filter { !$0.hasPrefix(".") && ConfigFiles.locate(ConfigFiles.panel($0), in: directory) != nil }.sorted()
    }

    /// A built-in theme or one in `themes/`, resolved as `config.jsonc`'s `theme` would be.
    public static func theme(_ name: String, in directory: URL) -> Result<Theme, ConfigErrors> {
        var resolver = ThemeResolver(files: ConfigFiles(directory: directory))
        let theme = resolver.resolve(name, from: "")
        let errors = resolver.files.issues.filter { $0.severity == .error }
        guard errors.isEmpty, let theme else { return .failure(ConfigErrors(issues: errors)) }
        return .success(theme)
    }

    /// `trigger`: a modifier key on its own, or a shortcut. Holding is the default for a key,
    /// toggling for a shortcut.
    private static func trigger(_ raw: RawTrigger, file: String, files: inout ConfigFiles) -> Trigger {
        var trigger = Trigger.fn
        if raw.key != nil && raw.shortcut != nil {
            files.error(file, "trigger", "set \"key\" or \"shortcut\", not both")
        } else if let value = raw.shortcut {
            switch Shortcut.parse(value) {
            case .success(let shortcut): trigger = Trigger(input: .shortcut(shortcut), mode: .toggle)
            case .failure(let error): files.error(file, "trigger.shortcut", error.message)
            }
        } else if let value = raw.key {
            if let key = Trigger.Key(rawValue: value) {
                trigger.input = .key(key)
            } else if value.lowercased() == "capslock" {
                files.error(file, "trigger.key", "caps lock can't be held, macOS locks it on press: map it to F18 and set \"shortcut\": \"F18\"")
            } else {
                files.error(file, "trigger.key", "unknown key \"\(value)\", expected one of \(Trigger.Key.allCases.map { "\"\($0.rawValue)\"" }.joined(separator: ", "))")
            }
        }
        if let value = raw.mode {
            if let mode = Trigger.Mode(rawValue: value) { trigger.mode = mode } else {
                files.error(file, "trigger.mode", "unknown mode \"\(value)\", expected \"hold\" or \"toggle\"")
            }
        }
        if let value = raw.holdMs {
            if !(50...2000).contains(value) {
                files.error(file, "trigger.holdMs", "must be between 50 and 2000, got \(value)")
            } else if trigger.mode == .toggle {
                files.warning(file, "trigger.holdMs", "only applies with \"mode\": \"hold\"")
            } else {
                trigger.holdMilliseconds = value
            }
        }
        return trigger
    }

    /// Resolves a `panels` entry to its panel. The size here wins over the panel's own.
    private static func tile(_ ref: RawPanelRef, path: String, config: String, files: inout ConfigFiles) -> Tile? {
        guard let name = ref.panel, !name.isEmpty else {
            files.error(config, path, "missing \"panel\"")
            return nil
        }
        let start = files.issues.count
        func at(_ key: String) -> String { path.isEmpty ? "" : "\(path).\(key)" }
        var refSize: TileSize?
        if let value = ref.size {
            refSize = TileSize(rawValue: value)
            if refSize == nil { files.error(config, at("size"), sizeMessage(value)) }
        }

        guard !name.contains("/"), !name.hasPrefix(".") else {
            files.error(config, at("panel"), "\"\(name)\" isn't a panel name")
            return nil
        }
        guard files.exists(ConfigFiles.panel(name)) else {
            files.error(config, at("panel"), "no panel \"\(name)\": create \(ConfigFiles.panel(name)).jsonc")
            return nil
        }
        let file = files.locate(ConfigFiles.panel(name))
        guard let raw = files.read(RawPanel.self, from: file) else { return nil }

        let kinds = (Tile.Kind.allCases.map(\.rawValue) + ContentType.allCases.map(\.rawValue)).map { "\"\($0)\"" }.joined(separator: ", ")
        var kind: Tile.Kind?
        var content: ContentType?
        switch raw.type {
        case let type?:
            if let parsed = ContentType(rawValue: type) {
                kind = .script
                content = parsed
            } else {
                kind = Tile.Kind(rawValue: type)
                if kind == nil { files.error(file, "type", "unknown type \"\(type)\", expected one of \(kinds)") }
            }
        case nil:
            files.error(file, "type", "missing \"type\", expected one of \(kinds)")
        }

        var mode = Tile.Mode.interval
        if let value = raw.mode {
            if let parsed = Tile.Mode(rawValue: value) { mode = parsed } else {
                files.error(file, "mode", "unknown mode \"\(value)\", expected \"interval\" or \"stream\"")
            }
        }

        var source: URL?
        if let path = raw.file {
            if content != .markdown {
                files.error(file, "file", "only a markdown panel can read a file")
            } else if path.trimmingCharacters(in: .whitespaces).isEmpty {
                files.error(file, "file", "can't be empty")
            } else {
                let expanded = NSString(string: path).expandingTildeInPath
                source = expanded.hasPrefix("/") ? URL(fileURLWithPath: expanded)
                    : files.directory.appending(path: "panels/\(name)").appending(path: expanded).standardizedFileURL
            }
        }
        let command = raw.command?.trimmingCharacters(in: .whitespaces) ?? ""
        if source != nil, !command.isEmpty {
            files.error(file, "command", "a panel reads either a file or a command's output, not both")
        } else if command.isEmpty, raw.file == nil, let kind {
            files.error(file, "command", content == .markdown ? "a markdown panel needs a command or a file" : "a \(kind.rawValue) panel needs a command")
        }
        if source != nil, mode == .stream {
            files.error(file, "mode", "a file panel reloads when the file changes, so it can't stream")
        }

        var history: Int?
        if let value = raw.history {
            if content != .chart {
                files.error(file, "history", "only a chart panel keeps a history")
            } else if ChartHistory.range.contains(value) {
                history = value
            } else {
                files.error(file, "history", "\(value) is out of range, expected \(ChartHistory.range.lowerBound) to \(ChartHistory.range.upperBound)")
            }
        }

        var panelSize = TileSize.s
        if let value = raw.size {
            if let size = TileSize(rawValue: value) { panelSize = size } else { files.error(file, "size", sizeMessage(value)) }
        }
        let every = interval(raw.every, default: 60, minimum: minimumInterval, file: file, path: "every", files: &files)
        let timeout = interval(raw.timeout, default: 10, minimum: 0.1, file: file, path: "timeout", files: &files)

        var background = Tile.Background.same
        if let value = raw.background, let parsed = Self.background(value, file: file, path: "background", files: &files) { background = parsed }
        if let value = ref.background, let parsed = Self.background(value, file: config, path: at("background"), files: &files) { background = parsed }
        if mode == .stream || source != nil {
            if ref.background != nil {
                files.warning(config, at("background"), "only applies to interval panels that run a command")
            } else if raw.background != nil {
                files.warning(file, "background", "only applies to interval panels that run a command")
            }
        }
        let show = ref.show ?? true
        if !show, background == .off {
            files.warning(config, at("show"), "\"\(name)\" is hidden and doesn't run in the background, so it never runs")
        }

        var notify: NotifySettings? = NotifySettings()
        if let value = raw.notify { notify = Self.notify(value, onto: notify, file: file, path: "notify", files: &files) }
        if let value = ref.notify { notify = Self.notify(value, onto: notify, file: config, path: at("notify"), files: &files) }

        let requires = raw.requires ?? []
        for (index, tool) in requires.enumerated() where tool.isEmpty || tool.contains("/") {
            files.error(file, "requires[\(index)]", "\"\(tool)\" isn't a command name")
        }

        guard !files.issues[start...].contains(where: { $0.severity == .error }), let kind, let every, let timeout else { return nil }
        return Tile(
            panel: name, kind: kind, mode: mode, command: command, title: raw.title ?? name,
            size: refSize ?? panelSize, every: every, timeout: timeout, requires: requires,
            directory: files.directory.appending(path: "panels/\(name)"), content: content,
            history: history, file: source, background: background, show: show, notify: notify
        )
    }

    private static func sizeMessage(_ value: String) -> String {
        "unknown size \"\(value)\", expected \"s\", \"m\", \"l\" or \"xl\""
    }

    /// A `background` value, or nil when it's broken (with an error).
    private static func background(_ raw: RawBackground, file: String, path: String, files: inout ConfigFiles) -> Tile.Background? {
        switch raw {
        case .flag(true): .same
        case .flag(false): .off
        case .duration(let text):
            interval(text, default: 0, minimum: minimumInterval, file: file, path: path, files: &files).map { .every($0) }
        }
    }

    /// `notifications`, with defaults for what isn't set.
    private static func notifications(_ raw: RawNotifications?, file: String, files: inout ConfigFiles) -> NotificationSettings {
        var settings = NotificationSettings()
        guard let raw else { return settings }
        settings.enabled = raw.enabled ?? settings.enabled
        settings.sound = raw.sound ?? settings.sound
        settings.whileOpen = raw.whileOpen ?? settings.whileOpen
        if let text = raw.quietHours {
            settings.quietHours = QuietHours.parse(text)
            if settings.quietHours == nil {
                files.error(file, "notifications.quietHours", "can't read \"\(text)\", write it like \"22:00-07:00\"")
            }
        }
        return settings
    }

    /// A `notify` value applied onto what's set so far: nil is off.
    private static func notify(_ raw: RawNotify, onto current: NotifySettings?, file: String, path: String, files: inout ConfigFiles) -> NotifySettings? {
        guard case .on(let raw) = raw else { return nil }
        var settings = current ?? NotifySettings()
        if let sound = raw.sound { settings.sound = sound }
        if raw.minInterval != nil, let seconds = interval(raw.minInterval, default: 0, minimum: 1, file: file, path: "\(path).minInterval", files: &files) {
            settings.minInterval = seconds
        }
        if let values = raw.on {
            var events: Set<NotifyEvent> = []
            for (index, value) in values.enumerated() {
                if let event = NotifyEvent(rawValue: value) { events.insert(event) } else {
                    files.error(file, "\(path).on[\(index)]", "unknown event \"\(value)\", expected \"failed\", \"warning\" or \"error\"")
                }
            }
            settings.on = events
        }
        return settings
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
