import AppKit
import SwiftUI
import TjuvkikCore

/// The Framed Bento board: tiles on a 4×3 grid, placed from the config.
struct GlanceView: View {
    let model: GlanceModel
    let store: ConfigStore

    private let gap: CGFloat = 10

    var body: some View {
        let config = store.config
        GeometryReader { geometry in
            let cell = CGSize(
                width: (geometry.size.width - gap * CGFloat(BentoPacking.columns - 1)) / CGFloat(BentoPacking.columns),
                height: (geometry.size.height - gap * CGFloat(BentoPacking.rows - 1)) / CGFloat(BentoPacking.rows)
            )
            ForEach(Array(config.tiles.enumerated()), id: \.offset) { index, tile in
                if let slot = tile.slot {
                    let width = cell.width * CGFloat(slot.columns) + gap * CGFloat(slot.columns - 1)
                    let height = cell.height * CGFloat(slot.rows) + gap * CGFloat(slot.rows - 1)
                    TileView(tile: tile, theme: config.theme, index: index, isVisible: model.isVisible)
                        .frame(width: width, height: height)
                        .position(
                            x: (cell.width + gap) * CGFloat(slot.column) + width / 2,
                            y: (cell.height + gap) * CGFloat(slot.row) + height / 2
                        )
                }
            }
        }
        .padding(10)
        .environment(\.colorScheme, config.theme.appearance.colorScheme)
    }
}

private struct TileView: View {
    let tile: Tile
    let theme: Theme
    let index: Int
    let isVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let radius = CGFloat(theme.radius)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(tile.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(theme.secondaryText))
                Text(tile.kind.name)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(theme.tertiaryText))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color(theme.well), in: RoundedRectangle(cornerRadius: 4))
                Spacer()
                Text(tile.kind == .agents ? "live" : "every \(Duration.seconds(tile.every).formatted(.units(width: .narrow)))")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color(theme.tertiaryText))
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            if theme.blur && !reduceTransparency {
                ZStack {
                    VisualEffect(cornerRadius: radius, appearance: theme.appearance)
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color(theme.panel))
                }
            } else {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color(theme.panel).opacity(1))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color(theme.line)))
        .shadow(color: .black.opacity(theme.blur ? 0.18 : 0.35), radius: 18, y: 10)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible || reduceMotion ? 1 : 0.97)
        .animation(.easeOut(duration: 0.22).delay(Double(index) * 0.03), value: isVisible)
    }
}
