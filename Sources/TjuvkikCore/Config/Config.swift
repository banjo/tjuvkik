import Foundation

/// The validated config, read from the config directory by `ConfigLoader`.
public struct Config: Equatable, Sendable {
    public enum View: String, CaseIterable, Sendable { case bento, spotlight }
    public enum Layout: String, CaseIterable, Sendable { case framed, fullscreen, edges }

    /// What the trigger shows: the board, or Spotlight's list and preview.
    public var view: View
    public var layout: Layout
    /// The theme in light mode, and in dark mode. The same theme twice when config.jsonc names one.
    public var lightThemeName: String
    public var darkThemeName: String
    public var lightTheme: Theme
    public var darkTheme: Theme
    public var trigger: Trigger
    public var launchAtLogin: Bool
    public var tiles: [Tile]
    /// The panels shown in the menu bar, in order.
    public var menuBar: [String] = []
    /// When background runs stop.
    public var pause = Pause()
    /// `notifications`: how panels' notifications are delivered.
    public var notifications = NotificationSettings()
    /// How many cells the board has.
    public var grid = BoardGrid.standard
    /// How big the glance draws the board.
    public var zoom = Zoom.auto
    /// How dark the screen behind the glance gets, from 0 (not at all) to 1.
    public var dim: Double = 0
    /// What the keyboard focus starts on when the glance opens.
    public var focusOnOpen = FocusOnOpen.urgent
    /// The modifier that, with an arrow, moves the keyboard focus to the next tile that way.
    public var jumpKey = JumpKey.option
    /// Spotlight has a search field. Typing in it takes the keyboard from the app in front while
    /// Spotlight stays open.
    public var search = true

    public func theme(dark: Bool) -> Theme { dark ? darkTheme : lightTheme }

    /// `true` for `"dim"`.
    public static let defaultDim = 0.3

    public enum FocusOnOpen: String, CaseIterable, Sendable {
        /// The most urgent row: see `FocusNavigation.initial`.
        case urgent
        /// The row focused when the glance last closed, while it's still there.
        case last
    }

    /// `"jumpKey"`: held with an arrow, it jumps to the next tile instead of the next row.
    public enum JumpKey: String, CaseIterable, Sendable {
        case option, command, control, shift, none

        /// "⌥", or nil for none.
        public var symbol: String? {
            switch self {
            case .option: "⌥"
            case .command: "⌘"
            case .control: "⌃"
            case .shift: "⇧"
            case .none: nil
            }
        }
    }

    /// How big the glance draws the board: `"auto"` follows the screen, a number is fixed. Either
    /// is made smaller when the board wouldn't fit.
    public enum Zoom: Hashable, Sendable {
        case auto
        case fixed(Double)

        public static let range = 0.75...2.0
    }
    public func themeName(dark: Bool) -> String { dark ? darkThemeName : lightThemeName }

    /// When background runs stop.
    public struct Pause: Equatable, Sendable {
        /// While the screen is locked or the displays sleep.
        public var whenLocked: Bool
        /// While Low Power Mode is on.
        public var onLowPower: Bool

        public init(whenLocked: Bool = true, onLowPower: Bool = true) {
            self.whenLocked = whenLocked
            self.onLowPower = onLowPower
        }
    }
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

    /// The tile's name on the board: `id` in config.jsonc, or the panel's name. Unique.
    public var id: String
    /// The panel's name: its folder in `panels/`.
    public var panel: String
    /// The options the panel declares, sorted by name.
    public var declaredOptions: [PanelOption] = []
    /// Each option's value: the tile's, else the default. Unset ones without a default are missing.
    public var options: [String: OptionValue] = [:]
    public var kind: Kind
    public var mode: Mode
    public var command: String
    public var title: String
    /// From panel.jsonc, for the settings window.
    public var description: String?
    public var author: String?
    public var version: String?
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
    /// How a script panel's output is drawn, when panel.jsonc's `type` names one. Otherwise the
    /// output's top-level key decides.
    public var content: ContentType?
    /// How many values a chart panel keeps when its script prints only the current one.
    public var history: Int?
    /// A markdown panel's file, read instead of running a command and reloaded when it changes.
    public var file: URL?
    /// When an interval panel runs while the glance is closed.
    public var background: Background = .same
    /// False: the panel runs, for the menu bar, but has no spot on the grid.
    public var show = true
    /// Picked first when the glance opens for the keyboard, after urgent rows in it.
    public var focus = false
    /// What the panel notifies about; nil: it never notifies.
    public var notify: NotifySettings? = NotifySettings()

    /// When an interval panel runs while the glance is closed.
    public enum Background: Equatable, Sendable {
        /// On `every`, as while glancing. The default.
        case same
        /// This many seconds apart.
        case every(Double)
        /// Not at all: only while the glance is open.
        case off
    }

    /// What the tile's header calls it: "script", "cli", or the content type.
    public var typeName: String { content?.rawValue ?? kind.rawValue }
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
