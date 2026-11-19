import AppKit
import SwiftUI
import TjuvkikCore

extension Theme {
    /// Text at `size` points before the theme's scale and zoom, in its font.
    func font(_ size: CGFloat, weight: Font.Weight = .regular, mono: Bool = false, rounded: Bool = false) -> Font {
        let size = size * font.scale * zoom
        if mono {
            if let name = font.mono { return .custom(name, size: size).weight(weight) }
            return .system(size: size, weight: weight, design: .monospaced)
        }
        if let name = font.family { return .custom(name, size: size).weight(weight) }
        return .system(size: size, weight: weight, design: rounded ? .rounded : .default)
    }

    /// The same, for measuring with AppKit.
    func nsFont(_ size: CGFloat, weight: NSFont.Weight = .regular, mono: Bool = false) -> NSFont {
        let size = size * font.scale * zoom
        let family = mono ? font.mono : font.family
        if let family {
            let descriptor = NSFontDescriptor(fontAttributes: [.family: family, .traits: [NSFontDescriptor.TraitKey.weight: weight]])
            if let font = NSFont(descriptor: descriptor, size: size) { return font }
        }
        return mono ? .monospacedSystemFont(ofSize: size, weight: weight) : .systemFont(ofSize: size, weight: weight)
    }
}

extension NSFont {
    /// The same font with tabular digits, as SwiftUI's `.monospacedDigit()` draws it.
    var monospacedDigits: NSFont {
        let digits: [NSFontDescriptor.FeatureKey: Int] = [.typeIdentifier: kNumberSpacingType, .selectorIdentifier: kMonospacedNumbersSelector]
        return NSFont(descriptor: fontDescriptor.addingAttributes([.featureSettings: [digits]]), size: pointSize) ?? self
    }
}
