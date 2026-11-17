import AppKit
import SwiftUI
import TjuvkikCore

extension Color {
    init(_ rgba: RGBA) {
        self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}

extension Theme.Appearance {
    var colorScheme: ColorScheme { self == .dark ? .dark : .light }
    var nsAppearance: NSAppearance? { NSAppearance(named: self == .dark ? .darkAqua : .aqua) }
}

extension Theme {
    func color(for tone: Tone?, default fallback: RGBA) -> Color {
        switch tone {
        case .warning: Color(warning)
        case .error: Color(error)
        case .success: Color(success)
        case .info: Color(info)
        case .accent: Color(accent)
        case .muted: Color(tertiaryText)
        case .normal, nil: Color(fallback)
        }
    }

    /// What a view draws behind something in `tone`: the theme's background for it, or `color` at `opacity`.
    func background(for tone: Tone?, color: Color, opacity: Double) -> Color {
        if let tone, let background = toneBackgrounds[tone] { return Color(background) }
        return color.opacity(opacity)
    }
}
