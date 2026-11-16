import Foundation

/// `tjuvkik validate`: the config as the app loads it, plus every panel in `panels/`, including
/// ones `config.jsonc` doesn't show, so a broken panel is found before it's added.
public struct ConfigValidation: Equatable, Sendable {
    public var errors: [ConfigIssue]
    public var warnings: [ConfigIssue]
    /// Every panel folder found.
    public var panels: [String]
    /// The panels on the board, in order. Empty when the config has errors.
    public var shown: [String]

    public var isValid: Bool { errors.isEmpty }

    public static func check(_ directory: URL) -> ConfigValidation {
        guard ConfigFiles.locate(ConfigFiles.config, in: directory) != nil else {
            let path = (directory.path as NSString).abbreviatingWithTildeInPath
            return ConfigValidation(
                errors: [ConfigIssue(severity: .error, file: "config.jsonc", message: "not found in \(path)")],
                warnings: [], panels: ConfigLoader.panelNames(in: directory), shown: []
            )
        }
        var issues: [ConfigIssue] = []
        var shown: [String] = []
        switch ConfigLoader.load(from: directory) {
        case .success(let loaded):
            issues += loaded.warnings
            shown = loaded.config.tiles.filter { $0.slot != nil }.map(\.panel)
        case .failure(let failure):
            issues += failure.issues
        }
        let panels = ConfigLoader.panelNames(in: directory)
        for name in panels {
            if case .failure(let failure) = ConfigLoader.panel(name, in: directory) { issues += failure.issues }
        }
        // A panel on the board is checked twice: once by the config, once on its own.
        var seen: Set<String> = []
        issues = issues.filter { seen.insert($0.description).inserted }
        return ConfigValidation(
            errors: issues.filter { $0.severity == .error },
            warnings: issues.filter { $0.severity == .warning },
            panels: panels, shown: shown
        )
    }

    /// One line per issue, then what was checked.
    public var report: String {
        var lines = errors.map { "error: \($0)" } + warnings.map { "warning: \($0)" }
        let counted = [plural(errors.count, "error"), plural(warnings.count, "warning")].filter { !$0.hasPrefix("0 ") }
        let checked = "config.jsonc and \(plural(panels.count, "panel"))"
        if isValid {
            let board = "\(shown.count) on the board"
            lines.append("✓ \(checked) are valid, \(board)" + (counted.isEmpty ? "" : ", with \(counted.joined(separator: " and "))"))
        } else {
            lines.append("✗ \(counted.joined(separator: " and ")) in \(checked)")
        }
        return lines.joined(separator: "\n")
    }

    private func plural(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }
}
