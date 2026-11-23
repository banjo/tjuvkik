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

/// The system spinner's look: eight spokes, fading behind the brightest one as it steps round.
/// Drawn, not an AppKit `ProgressView`, so it takes the tone and shows in `tjuvkik preview` too.
/// The `progress.indicator` symbol can't do this: its spokes are all alike in one color, so
/// turning it by a spoke looks the same.
private struct SpinnerView: View {
    let size: CGFloat
    let color: Color
    let theme: Theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let side = theme.z(size * 0.95)
        TimelineView(.animation(minimumInterval: 1 / 12, paused: reduceMotion)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate * 12) % 8
            Canvas { canvas, area in
                let center = CGPoint(x: area.width / 2, y: area.height / 2)
                let radius = min(area.width, area.height) / 2
                let width = max(radius * 0.22, 1.2)
                for spoke in 0..<8 {
                    // The lead spoke is solid; each one behind it is fainter.
                    let behind = (step - spoke + 8) % 8
                    let angle = Double(spoke) * .pi / 4 - .pi / 2
                    var path = Path()
                    path.move(to: CGPoint(x: center.x + cos(angle) * radius * 0.45, y: center.y + sin(angle) * radius * 0.45))
                    path.addLine(to: CGPoint(x: center.x + cos(angle) * (radius - width / 2), y: center.y + sin(angle) * (radius - width / 2)))
                    canvas.stroke(path, with: .color(color.opacity(1 - Double(behind) * 0.1)), style: StrokeStyle(lineWidth: width, lineCap: .round))
                }
            }
            .frame(width: side, height: side)
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
