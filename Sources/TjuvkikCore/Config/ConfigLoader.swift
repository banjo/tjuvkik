import Foundation

public enum ConfigLoader {
    public static let minimumInterval: Double = 5

    /// Reads JSON with comments and trailing commas (JSON5), then validates it. Errors fail the
    /// load; warnings (like a value from a later version) fall back to the default and load.
    public static func parse(_ data: Data) -> Result<LoadedConfig, ConfigErrors> {
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        let raw: RawConfig
        do {
            raw = try decoder.decode(RawConfig.self, from: data)
        } catch let error as DecodingError {
            return .failure(ConfigErrors(issues: [describe(error)]))
        } catch {
            return .failure(ConfigErrors(issues: [.error("", error.localizedDescription)]))
        }
        return validate(raw)
    }

    static func validate(_ raw: RawConfig) -> Result<LoadedConfig, ConfigErrors> {
        var issues: [ConfigIssue] = []

        var view = Config.View.bento
        if let value = raw.view {
            switch Config.View(rawValue: value) {
            case .bento: break
            case .spotlight: issues.append(.warning("view", "\"spotlight\" isn't available yet, using \"bento\""))
            case nil: issues.append(.error("view", "unknown view \"\(value)\", expected \"bento\" or \"spotlight\""))
            }
            view = .bento
        }

        var layout = Config.Layout.framed
        if let value = raw.layout {
            switch Config.Layout(rawValue: value) {
            case .framed: break
            case .fullscreen, .edges: issues.append(.warning("layout", "\"\(value)\" isn't available yet, using \"framed\""))
            case nil: issues.append(.error("layout", "unknown layout \"\(value)\", expected \"framed\", \"fullscreen\" or \"edges\""))
            }
            layout = .framed
        }

        let themeName = raw.theme ?? "dark-glass"
        var themeIssues: [ConfigIssue] = []
        let theme = ThemeResolver.resolve(themeName, custom: raw.themes ?? [:], issues: &themeIssues)
        issues += themeIssues

        var hold = 250
        if let value = raw.trigger?.holdMs {
            if (50...2000).contains(value) { hold = value } else { issues.append(.error("trigger.holdMs", "must be between 50 and 2000, got \(value)")) }
        }

        var tiles = (raw.tiles ?? defaultTiles).enumerated().compactMap { index, tile in
            validateTile(tile, path: "tiles[\(index)]", issues: &issues)
        }
        let slots = BentoPacking.pack(tiles.map(\.size))
        for index in tiles.indices {
            tiles[index].slot = slots[index]
            if slots[index] == nil {
                issues.append(.warning("tiles[\(index)]", "\"\(tiles[index].title)\" doesn't fit on the 4×3 grid and is left out"))
            }
        }

        let errors = issues.filter { $0.severity == .error }
        guard errors.isEmpty, let theme else { return .failure(ConfigErrors(issues: errors)) }
        let config = Config(
            view: view, layout: layout, themeName: themeName, theme: theme,
            holdMilliseconds: hold, launchAtLogin: raw.launchAtLogin ?? true, tiles: tiles
        )
        return .success(LoadedConfig(config: config, warnings: issues))
    }

    private static let defaultTiles = [RawTile(module: "agents", size: "xl")]

    private static func validateTile(_ raw: RawTile, path: String, issues: inout [ConfigIssue]) -> Tile? {
        let start = issues.count
        let kind: Tile.Kind?
        var title = raw.title

        switch (raw.module, raw.type) {
        case ("agents", nil):
            kind = .agents
            title = title ?? "Agents"
        case (let module?, nil):
            issues.append(.error("\(path).module", "unknown module \"\(module)\", expected \"agents\""))
            kind = nil
        case (nil, let type?):
            guard type == "script" || type == "cli" else {
                issues.append(.error("\(path).type", "unknown type \"\(type)\", expected \"script\" or \"cli\""))
                kind = nil
                break
            }
            guard let command = raw.command?.trimmingCharacters(in: .whitespaces), !command.isEmpty else {
                issues.append(.error("\(path).command", "a \(type) tile needs a command"))
                kind = nil
                break
            }
            kind = type == "script" ? .script(command: command) : .cli(command: command)
            if title == nil { issues.append(.error("\(path).title", "a \(type) tile needs a title")) }
        case (nil, nil):
            issues.append(.error(path, "a tile needs \"module\" or \"type\""))
            kind = nil
        case (_?, _?):
            issues.append(.error(path, "a tile has either \"module\" or \"type\", not both"))
            kind = nil
        }

        let sizeName = raw.size ?? "s"
        let size = TileSize(rawValue: sizeName)
        if size == nil { issues.append(.error("\(path).size", "unknown size \"\(sizeName)\", expected \"s\", \"m\", \"l\" or \"xl\"")) }

        let every = interval(raw.every, default: 60, minimum: minimumInterval, path: "\(path).every", issues: &issues)
        let timeout = interval(raw.timeout, default: 10, minimum: 0.1, path: "\(path).timeout", issues: &issues)

        guard issues.count == start, let kind, let title, let size, let every, let timeout else { return nil }
        return Tile(kind: kind, title: title, size: size, every: every, timeout: timeout)
    }

    private static func interval(_ text: String?, default value: Double, minimum: Double, path: String, issues: inout [ConfigIssue]) -> Double? {
        guard let text else { return value }
        guard let seconds = Interval.seconds(text) else {
            issues.append(.error(path, "can't read \"\(text)\", write it like \"30s\", \"5m\" or \"1h\""))
            return nil
        }
        guard seconds >= minimum else {
            issues.append(.error(path, "must be at least \(minimum.formatted())s, got \"\(text)\""))
            return nil
        }
        return seconds
    }

    private static func describe(_ error: DecodingError) -> ConfigIssue {
        func path(_ codingPath: [any CodingKey]) -> String {
            codingPath.reduce("") { result, key in
                if let index = key.intValue { return "\(result)[\(index)]" }
                return result.isEmpty ? key.stringValue : "\(result).\(key.stringValue)"
            }
        }
        switch error {
        case .typeMismatch(let type, let context):
            return .error(path(context.codingPath), "expected \(typeName(type))")
        case .valueNotFound(let type, let context):
            return .error(path(context.codingPath), "expected \(typeName(type)), got null")
        case .keyNotFound(let key, let context):
            return .error(path(context.codingPath), "missing \"\(key.stringValue)\"")
        case .dataCorrupted(let context):
            let underlying = (context.underlyingError as NSError?)?.userInfo[NSDebugDescriptionErrorKey] as? String
            return .error(path(context.codingPath), underlying ?? context.debugDescription)
        @unknown default:
            return .error("", error.localizedDescription)
        }
    }

    private static func typeName(_ type: Any.Type) -> String {
        switch type {
        case is String.Type: "a string"
        case is Bool.Type: "true or false"
        case is Int.Type, is Double.Type: "a number"
        case is [RawTile].Type: "a list of tiles"
        default: "an object"
        }
    }
}
