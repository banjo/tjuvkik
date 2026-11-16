import Foundation

/// The validated config. Built from `config.json` by `ConfigLoader`.
public struct Config: Equatable, Sendable {
    public enum View: String, Sendable { case bento, spotlight }
    public enum Layout: String, Sendable { case framed, fullscreen, edges }

    public var view: View
    public var layout: Layout
    public var themeName: String
    public var theme: Theme
    public var holdMilliseconds: Int
    public var launchAtLogin: Bool
    public var tiles: [Tile]
}

public struct Tile: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case agents
        case script(command: String)
        case cli(command: String)

        public var name: String {
            switch self {
            case .agents: "native"
            case .script: "script"
            case .cli: "cli"
            }
        }
    }

    public var kind: Kind
    public var title: String
    public var size: TileSize
    /// Seconds between refreshes.
    public var every: Double
    /// Seconds a command may run.
    public var timeout: Double
    /// Where the tile sits on the grid; nil when it didn't fit.
    public var slot: GridSlot?
}

/// A problem in the config, with where it is (`tiles[2].size`).
public struct ConfigIssue: Equatable, Sendable, CustomStringConvertible {
    public enum Severity: Sendable { case error, warning }

    public var severity: Severity
    public var path: String
    public var message: String

    public var description: String { path.isEmpty ? message : "\(path): \(message)" }

    static func error(_ path: String, _ message: String) -> ConfigIssue { .init(severity: .error, path: path, message: message) }
    static func warning(_ path: String, _ message: String) -> ConfigIssue { .init(severity: .warning, path: path, message: message) }
}

public struct LoadedConfig: Equatable, Sendable {
    public var config: Config
    public var warnings: [ConfigIssue]
}

public struct ConfigErrors: Error, Equatable, Sendable {
    public var issues: [ConfigIssue]
}
