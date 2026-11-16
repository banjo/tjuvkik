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
