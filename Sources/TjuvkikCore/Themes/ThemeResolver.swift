import Foundation

/// Resolves a theme name to tokens. Custom themes live in `themes/<name>.jsonc`, extend a built-in
/// or another custom theme (dark glass when unset), and override only the tokens they set.
struct ThemeResolver {
    var files: ConfigFiles

    /// `file` is the config file that names the theme.
    mutating func resolve(_ name: String, from file: String, path: String = "theme") -> Theme? {
        resolve(name, seen: [], file: file, path: path)
    }

    private mutating func resolve(_ name: String, seen: [String], file: String, path: String) -> Theme? {
        if seen.contains(name) {
            files.error(file, path, "themes extend each other in a loop: \((seen + [name]).joined(separator: " → "))")
            return nil
        }
        if let theme = Theme.builtIn[name] {
            if let file = ConfigFiles.locate(ConfigFiles.theme(name), in: files.directory) {
                files.warning(file, "", "\"\(name)\" is a built-in theme; rename the file to use it")
            }
            return theme
        }
        guard !name.contains("/"), files.exists(ConfigFiles.theme(name)) else {
            let known = (Theme.builtIn.keys.sorted() + files.themeNames()).map { "\"\($0)\"" }.joined(separator: ", ")
            files.error(file, path, "unknown theme \"\(name)\", expected one of \(known)")
            return nil
        }
        let themeFile = files.locate(ConfigFiles.theme(name))
        guard let raw = files.read(RawTheme.self, from: themeFile),
              var theme = resolve(raw.extends ?? "dark-glass", seen: seen + [name], file: themeFile, path: "extends")
        else { return nil }
        apply(raw, to: &theme, file: themeFile)
        return theme
    }

    private mutating func apply(_ raw: RawTheme, to theme: inout Theme, file: String) {
        if let value = raw.appearance {
            if let appearance = Theme.Appearance(rawValue: value) { theme.appearance = appearance } else {
                files.error(file, "appearance", "expected \"dark\" or \"light\", got \"\(value)\"")
            }
        }
        if let blur = raw.blur { theme.blur = blur }
        if let radius = raw.radius {
            if (0...40).contains(radius) { theme.radius = radius } else {
                files.error(file, "radius", "must be between 0 and 40")
            }
        }
        let colors: [(String, String?, WritableKeyPath<Theme, RGBA>)] = [
            ("panel", raw.panel, \.panel), ("well", raw.well, \.well),
            ("text", raw.text, \.text), ("secondaryText", raw.secondaryText, \.secondaryText),
            ("tertiaryText", raw.tertiaryText, \.tertiaryText), ("line", raw.line, \.line),
            ("warning", raw.warning, \.warning), ("error", raw.error, \.error), ("success", raw.success, \.success),
            ("info", raw.info, \.info), ("accent", raw.accent, \.accent),
        ]
        for (key, value, keyPath) in colors {
            guard let value else { continue }
            if let color = color(value, file: file, path: key) { theme[keyPath: keyPath] = color }
        }

        if let value = raw.material {
            if let material = Theme.Material(rawValue: value) { theme.material = material } else {
                files.error(file, "material", "unknown material \"\(value)\", expected \"hud\", \"popover\", \"menu\", \"sidebar\" or \"underWindow\"")
            }
        }
        if let font = raw.font {
            if let family = font.family {
                if InstalledFonts.has(family) { theme.font.family = family } else {
                    files.warning(file, "font.family", "\"\(family)\" isn't installed, using the system font")
                }
            }
            if let mono = font.mono {
                if InstalledFonts.has(mono) { theme.font.mono = mono } else {
                    files.warning(file, "font.mono", "\"\(mono)\" isn't installed, using the system's monospaced font")
                }
            }
            number(font.scale, in: Theme.Fonts.scales, file: file, path: "font.scale") { theme.font.scale = $0 }
        }
        if let board = raw.board {
            number(board.gap, in: Theme.Board.gaps, file: file, path: "board.gap") { theme.board.gap = $0 }
            number(board.inset, in: Theme.Board.insets, file: file, path: "board.inset") { theme.board.inset = $0 }
        }
        if let tile = raw.tile {
            number(tile.border, in: Theme.TileStyle.borders, file: file, path: "tile.border") { theme.tile.border = $0 }
            number(tile.padding, in: Theme.TileStyle.paddings, file: file, path: "tile.padding") { theme.tile.padding = $0 }
            if let shadow = tile.shadow { theme.tile.shadow = shadow }
            if let uppercase = tile.header?.uppercase { theme.tile.uppercaseTitle = uppercase }
            if let kind = tile.header?.kind { theme.tile.showKind = kind }
            if let interval = tile.header?.interval { theme.tile.showInterval = interval }
        }
        for (key, style) in (raw.tones ?? [:]).sorted(by: { $0.key < $1.key }) {
            guard let tone = Tone(rawValue: key), tone != .normal else {
                files.error(file, "tones.\(key)", "unknown tone, expected \"muted\", \"warning\", \"error\", \"success\", \"info\" or \"accent\"")
                continue
            }
            if let value = style.background, let color = color(value, file: file, path: "tones.\(key).background") {
                theme.toneBackgrounds[tone] = color
            }
        }
    }

    private mutating func color(_ value: String, file: String, path: String) -> RGBA? {
        guard let color = RGBA(hex: value) else {
            files.error(file, path, "can't read color \"\(value)\", write it like \"#ff79c6\" or \"#ff79c680\"")
            return nil
        }
        return color
    }

    private mutating func number(_ value: Double?, in range: ClosedRange<Double>, file: String, path: String, set: (Double) -> Void) {
        guard let value else { return }
        if range.contains(value) { set(value) } else {
            files.error(file, path, "must be between \(range.lowerBound.secondsText) and \(range.upperBound.secondsText), got \(value.secondsText)")
        }
    }
}
