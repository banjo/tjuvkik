import Foundation

/// The validated config, read from the config directory by `ConfigLoader`.
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

/// A panel placed on the board.
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

    /// The panel's name: its folder in `panels/`, or a built-in like `agents`.
    public var panel: String
    public var kind: Kind
    public var title: String
    public var size: TileSize
    /// Seconds between refreshes.
    public var every: Double
    /// Seconds a command may run.
    public var timeout: Double
    /// Where commands run: the panel's folder. Nil for built-ins.
    public var directory: URL?
    /// Where the tile sits on the grid; nil when it didn't fit.
    public var slot: GridSlot?
}

/// A problem in the config, with the file and where in it (`panels/pods/panel.jsonc`, `every`).
public struct ConfigIssue: Equatable, Sendable, CustomStringConvertible {
    public enum Severity: Sendable { case error, warning }

    public var severity: Severity
    public var file: String
    public var path: String
    public var message: String

    public init(severity: Severity, file: String, path: String = "", message: String) {
        self.severity = severity
        self.file = file
        self.path = path
        self.message = message
    }

    public var description: String {
        ([file, path].filter { !$0.isEmpty } + [message]).joined(separator: ": ")
    }
}

public struct LoadedConfig: Equatable, Sendable {
    public var config: Config
    public var warnings: [ConfigIssue]
}

public struct ConfigErrors: Error, Equatable, Sendable {
    public var issues: [ConfigIssue]
}
