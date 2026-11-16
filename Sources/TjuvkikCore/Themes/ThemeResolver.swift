import Foundation

/// Resolves a theme name to tokens. Custom themes live in `themes/<name>.jsonc`, extend a built-in
/// or another custom theme (dark glass when unset), and override only the tokens they set.
struct ThemeResolver {
    var files: ConfigFiles

    /// `file` is the config file that names the theme.
    mutating func resolve(_ name: String, from file: String) -> Theme? {
        resolve(name, seen: [], file: file, path: "theme")
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
            if let color = RGBA(hex: value) { theme[keyPath: keyPath] = color } else {
                files.error(file, key, "can't read color \"\(value)\", write it like \"#ff79c6\" or \"#ff79c680\"")
            }
        }
    }
}
