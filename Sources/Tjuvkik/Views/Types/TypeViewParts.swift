import SwiftUI
import TjuvkikCore

/// The three layouts each content type has. An xl tile uses l's.
enum TileLayout {
    case s, m, l

    init(_ size: TileSize) {
        switch size {
        case .s: self = .s
        case .m: self = .m
        case .l, .xl: self = .l
        }
    }
}

/// How far content may reach past its frame into the tile's padding, to draw up to the tile's
/// edge: the s chart's sparkline. The tile clips to its rounded shape.
struct TileBleed: Equatable {
    var horizontal: CGFloat = 0
    var bottom: CGFloat = 0
}

private struct TileBleedKey: EnvironmentKey {
    static let defaultValue = TileBleed()
}

extension EnvironmentValues {
    var tileBleed: TileBleed {
        get { self[TileBleedKey.self] }
        set { self[TileBleedKey.self] = newValue }
    }
}

/// A big number with a smaller unit after it: "99.71 %".
struct ValueText: View {
    let value: String
    var unit: String?
    let size: CGFloat
    var unitSize: CGFloat?
    var color: Color?
    let theme: Theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.z(2)) {
            Text(value)
                .font(theme.font(size, weight: .semibold).monospacedDigit())
                .tracking(theme.z(-0.02 * size))
                .foregroundStyle(color ?? Color(theme.text))
            if let unit, !unit.isEmpty {
                Text(unit)
                    .font(theme.font(unitSize ?? (size * 0.5).rounded(), weight: .medium))
                    .foregroundStyle(Color(theme.secondaryText))
            }
        }
        .lineLimit(1)
    }
}

/// A change in its tone, then what it's against: "▲ 4  vs last week".
struct DeltaLine: View {
    let delta: String?
    let tone: Tone?
    let vs: String?
    var deltaSize: CGFloat = 11.5
    var vsSize: CGFloat = 10.5
    let theme: Theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.z(6)) {
            if let delta {
                Text(delta)
                    .font(theme.font(deltaSize, weight: .medium).monospacedDigit())
                    .foregroundStyle(theme.color(for: tone, default: theme.secondaryText))
                    .fixedSize()
            }
            if let vs {
                Text(vs)
                    .font(theme.font(vsSize))
                    .foregroundStyle(Color(theme.tertiaryText))
                    .truncationMode(.tail)
            }
        }
        .lineLimit(1)
    }
}

extension View {
    /// The darker inset that cells and chips sit on.
    func well(_ theme: Theme, radius: CGFloat? = nil) -> some View {
        background(Color(theme.well), in: RoundedRectangle(cornerRadius: radius ?? theme.z(10), style: .continuous))
    }
}
