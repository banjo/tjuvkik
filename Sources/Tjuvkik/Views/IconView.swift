import SwiftUI
import TjuvkikCore

/// A script's `icon`: text as is, a symbol in `color`, or a spinner. See `Icon`.
struct IconView: View {
    let icon: Icon
    /// The font size, before the theme's zoom.
    let size: CGFloat
    let color: Color
    let theme: Theme

    var body: some View {
        switch icon {
        case .text(let text):
            Text(text).font(theme.font(size))
        case .symbol(let name, let effect):
            Image(systemName: name)
                .font(theme.font(size * 0.92, weight: .medium))
                .foregroundStyle(color)
                .repeating(effect)
        case .spinner:
            SpinnerView(size: size, color: color, theme: theme)
        }
    }
}

/// The system spinner's look, its eight spokes turning a step at a time. Drawn, not an AppKit
/// `ProgressView`, so it takes the tone and shows in `tjuvkik preview` too.
private struct SpinnerView: View {
    let size: CGFloat
    let color: Color
    let theme: Theme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 12)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate * 12) % 8
            Image(systemName: "progress.indicator")
                .font(theme.font(size * 0.92, weight: .medium))
                .foregroundStyle(color)
                .rotationEffect(.degrees(Double(step) * 45))
        }
    }
}

private extension View {
    /// Repeats `effect` while it's on screen, or holds still with Reduce Motion on.
    @ViewBuilder
    func repeating(_ effect: Icon.Effect?) -> some View {
        modifier(SymbolEffectModifier(effect: effect))
    }
}

private struct SymbolEffectModifier: ViewModifier {
    let effect: Icon.Effect?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        switch reduceMotion ? nil : effect {
        case nil: content
        case .pulse: content.symbolEffect(.pulse, options: .repeat(.continuous))
        case .breathe: content.symbolEffect(.breathe, options: .repeat(.continuous))
        case .rotate: content.symbolEffect(.rotate, options: .repeat(.continuous))
        case .bounce: content.symbolEffect(.bounce, options: .repeat(.periodic(delay: 0.6)))
        case .wiggle: content.symbolEffect(.wiggle, options: .repeat(.periodic(delay: 0.6)))
        }
    }
}
