import Foundation

/// The validated config, read from the config directory by `ConfigLoader`.
public struct Config: Equatable, Sendable {
    public enum View: String, CaseIterable, Sendable { case bento, spotlight }
    public enum Layout: String, CaseIterable, Sendable { case framed, fullscreen, edges }

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
    public enum Kind: String, Equatable, Sendable, CaseIterable {
        /// Prints rows as JSON.
        case script
        /// Output shown as is.
        case cli
    }

    public enum Mode: String, Equatable, Sendable, CaseIterable {
        /// Runs every `every` seconds, and must finish within `timeout`.
        case interval
        /// Keeps running: each line a script prints is a new JSON document, and a cli panel shows
        /// the latest lines. Restarted if it exits.
        case stream
    }

    /// The panel's name: its folder in `panels/`.
    public var panel: String
    public var kind: Kind
    public var mode: Mode
    public var command: String
    public var title: String
    public var size: TileSize
    /// Seconds between refreshes, for interval panels.
    public var every: Double
    /// Seconds a run may take, for interval panels.
    public var timeout: Double
    /// Tools that must be on PATH, like `gh`.
    public var requires: [String]
    /// Where the command runs: the panel's folder.
    public var directory: URL
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
