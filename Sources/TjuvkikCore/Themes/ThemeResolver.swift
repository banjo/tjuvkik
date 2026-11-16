import Foundation

/// Resolves a theme name to tokens. Custom themes extend a built-in or another custom theme
/// (dark glass when unset) and override only the tokens they set.
enum ThemeResolver {
    static func resolve(_ name: String, custom: [String: RawTheme], issues: inout [ConfigIssue]) -> Theme? {
        resolve(name, custom: custom, seen: [], path: "theme", issues: &issues)
    }

    private static func resolve(_ name: String, custom: [String: RawTheme], seen: [String], path: String, issues: inout [ConfigIssue]) -> Theme? {
        if seen.contains(name) {
            issues.append(.error("themes.\(name).extends", "themes extend each other in a loop: \((seen + [name]).joined(separator: " → "))"))
            return nil
        }
        guard let raw = custom[name] else {
            if let theme = Theme.builtIn[name] { return theme }
            let known = (Theme.builtIn.keys.sorted() + custom.keys.sorted()).map { "\"\($0)\"" }.joined(separator: ", ")
            issues.append(.error(path, "unknown theme \"\(name)\", expected one of \(known)"))
            return nil
        }
        guard var theme = resolve(raw.extends ?? "dark-glass", custom: custom, seen: seen + [name], path: "themes.\(name).extends", issues: &issues) else {
            return nil
        }
        apply(raw, to: &theme, path: "themes.\(name)", issues: &issues)
        return theme
    }

    private static func apply(_ raw: RawTheme, to theme: inout Theme, path: String, issues: inout [ConfigIssue]) {
        if let value = raw.appearance {
            if let appearance = Theme.Appearance(rawValue: value) { theme.appearance = appearance } else {
                issues.append(.error("\(path).appearance", "expected \"dark\" or \"light\", got \"\(value)\""))
            }
        }
        if let blur = raw.blur { theme.blur = blur }
        if let radius = raw.radius {
            if (0...40).contains(radius) { theme.radius = radius } else {
                issues.append(.error("\(path).radius", "must be between 0 and 40"))
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
                issues.append(.error("\(path).\(key)", "can't read color \"\(value)\", write it like \"#ff79c6\" or \"#ff79c680\""))
            }
        }
    }
}
