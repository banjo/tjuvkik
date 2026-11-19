import Foundation

public struct RGBA: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// `#rgb`, `#rrggbb` or `#rrggbbaa`.
    public init?(hex: String) {
        var digits = hex.trimmingCharacters(in: .whitespaces)
        guard digits.hasPrefix("#") else { return nil }
        digits.removeFirst()
        if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
        if digits.count == 6 { digits += "ff" }
        guard digits.count == 8, let value = UInt32(digits, radix: 16) else { return nil }
        red = Double((value >> 24) & 0xff) / 255
        green = Double((value >> 16) & 0xff) / 255
        blue = Double((value >> 8) & 0xff) / 255
        alpha = Double(value & 0xff) / 255
    }

    /// The same color, fully opaque. For Reduce Transparency.
    public var opaque: RGBA {
        RGBA(red: red, green: green, blue: blue)
    }
}

/// The tokens every theme sets. Views only read these, so a theme is just a set of values.
public struct Theme: Equatable, Sendable {
    public enum Appearance: String, CaseIterable, Sendable { case dark, light }

    public var appearance: Appearance
    /// Blur what's behind the tiles. Without it, `panel` is drawn solid.
    public var blur: Bool
    public var panel: RGBA
    public var well: RGBA
    public var text: RGBA
    public var secondaryText: RGBA
    public var tertiaryText: RGBA
    public var line: RGBA
    public var warning: RGBA
    public var error: RGBA
    public var success: RGBA
    public var info: RGBA
    public var accent: RGBA
    public var radius: Double
    /// The glass behind the tiles, when `blur` is on.
    public var material = Material.hud
    public var font = Fonts()
    public var board = Board()
    public var tile = TileStyle()
    /// Backgrounds for tones that set one. Others use the tone's color, faded.
    public var toneBackgrounds: [Tone: RGBA] = [:]
    /// How much bigger the glance draws everything: set by `zoomed(_:)`, never by a theme file.
    public private(set) var zoom: Double = 1
}

extension Theme {
    /// The theme for a glance drawn `zoom` times its size: the sizes it sets are multiplied here,
    /// and views multiply their own with `z(_:)`. Text scales in `font(_:)`.
    public func zoomed(_ zoom: Double) -> Theme {
        var theme = self
        let factor = zoom / self.zoom
        theme.zoom = zoom
        theme.radius *= factor
        theme.board.gap *= factor
        theme.board.inset *= factor
        theme.tile.padding *= factor
        theme.tile.border *= factor
        return theme
    }

    /// A size in points, at the theme's zoom.
    public func z(_ points: CGFloat) -> CGFloat { points * CGFloat(zoom) }
}

extension Theme {
    public enum Material: String, CaseIterable, Sendable { case hud, popover, menu, sidebar, underWindow }

    public struct Fonts: Equatable, Sendable {
        /// Nil: the system font.
        public var family: String?
        /// Nil: the system's monospaced font.
        public var mono: String?
        public var scale: Double = 1
        public static let scales = 0.85...1.25

        public init() {}
    }

    public struct Board: Equatable, Sendable {
        public var gap: Double = 10
        public var inset: Double = 10
        public static let gaps = 0.0...24
        public static let insets = 0.0...40

        public init() {}
    }

    public struct TileStyle: Equatable, Sendable {
        public var border: Double = 1
        public var shadow = true
        public var padding: Double = 12
        public var uppercaseTitle = false
        public var showKind = true
        public var showInterval = true
        public static let borders = 0.0...4
        public static let paddings = 6.0...20

        public init() {}
    }
}

extension Theme {
    private static func hex(_ value: String) -> RGBA { RGBA(hex: value)! }

    public static let darkGlass = Theme(
        appearance: .dark, blur: true,
        panel: RGBA(red: 30 / 255, green: 31 / 255, blue: 41 / 255, alpha: 0.55),
        well: RGBA(red: 0, green: 0, blue: 0, alpha: 0.28),
        text: hex("#f8f8f2"),
        secondaryText: RGBA(red: 248 / 255, green: 248 / 255, blue: 242 / 255, alpha: 0.58),
        tertiaryText: RGBA(red: 248 / 255, green: 248 / 255, blue: 242 / 255, alpha: 0.36),
        line: RGBA(red: 1, green: 1, blue: 1, alpha: 0.08),
        warning: hex("#ffb86c"), error: hex("#ff6e6e"), success: hex("#50fa7b"), info: hex("#8be9fd"), accent: hex("#bd93f9"),
        radius: 16
    )

    public static let lightGlass = Theme(
        appearance: .light, blur: true,
        panel: RGBA(red: 246 / 255, green: 246 / 255, blue: 248 / 255, alpha: 0.6),
        well: RGBA(red: 0, green: 0, blue: 0, alpha: 0.04),
        text: hex("#1d1d1f"),
        secondaryText: RGBA(red: 0, green: 0, blue: 0, alpha: 0.56),
        tertiaryText: RGBA(red: 0, green: 0, blue: 0, alpha: 0.38),
        line: RGBA(red: 0, green: 0, blue: 0, alpha: 0.08),
        warning: hex("#c45a00"), error: hex("#d70015"), success: hex("#1d8a3e"), info: hex("#0071a4"), accent: hex("#7d3fc2"),
        radius: 16
    )

    public static let dracula = Theme(
        appearance: .dark, blur: false,
        panel: hex("#282a36"),
        well: hex("#21222c"),
        text: hex("#f8f8f2"),
        secondaryText: hex("#a4a8c4"),
        tertiaryText: hex("#6272a4"),
        line: hex("#44475a"),
        warning: hex("#ffb86c"), error: hex("#ff5555"), success: hex("#50fa7b"), info: hex("#8be9fd"), accent: hex("#bd93f9"),
        radius: 10
    )

    public static let builtIn: [String: Theme] = [
        "dark-glass": darkGlass,
        "light-glass": lightGlass,
        "dracula": dracula,
    ]
}
