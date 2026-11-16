import AppKit
import SwiftUI
import TjuvkikCore

/// The Framed Bento board: tiles on a 4×3 grid, placed from the config.
struct GlanceView: View {
    let model: GlanceModel
    let store: ConfigStore
    let panels: PanelStore

    var body: some View {
        let config = store.config
        GeometryReader { geometry in
            let cell = BentoGeometry.cell(in: geometry.size)
            let gap = BentoGeometry.gap
            ForEach(Array(config.tiles.enumerated()), id: \.offset) { index, tile in
                if let slot = tile.slot {
                    let size = BentoGeometry.size(columns: slot.columns, rows: slot.rows, cell: cell)
                    TileView(tile: tile, state: panels.states[tile.panel], theme: config.theme, index: index, isVisible: model.isVisible)
                        .frame(width: size.width, height: size.height)
                        .position(
                            x: BentoGeometry.inset + (cell.width + gap) * CGFloat(slot.column) + size.width / 2,
                            y: BentoGeometry.inset + (cell.height + gap) * CGFloat(slot.row) + size.height / 2
                        )
                }
            }
        }
        .environment(\.colorScheme, config.theme.appearance.colorScheme)
    }
}

/// One panel: its header, its content and its last error. `solid` draws the background without
/// the blur, for rendering outside the glance.
struct TileView: View {
    let tile: Tile
    let state: PanelStore.State?
    let theme: Theme
    let index: Int
    let isVisible: Bool
    var solid = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let padding: CGFloat = 12

    var body: some View {
        let radius = CGFloat(theme.radius)
        // Content may draw into the padding at the sides, and at the bottom unless an error is
        // shown there.
        let bleed = TileBleed(horizontal: padding, bottom: state?.error == nil ? padding : 0)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(tile.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(theme.secondaryText))
                Text(state?.content?.type?.rawValue ?? tile.typeName)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(theme.tertiaryText))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color(theme.well), in: RoundedRectangle(cornerRadius: 4))
                Spacer()
                if state?.error != nil && state?.content != nil {
                    Text("stale").font(.system(size: 10.5, weight: .medium)).foregroundStyle(Color(theme.warning))
                } else {
                    Text(tile.mode == .stream ? "live" : "every \(Duration.seconds(tile.every).formatted(.units(allowed: [.days, .hours, .minutes, .seconds], width: .narrow)))")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(theme.tertiaryText))
                }
            }
            content
                .environment(\.tileBleed, bleed)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipShape(BleedClip(bleed: bleed))
            if let error = state?.error {
                Text(error)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color(theme.error))
                    .lineLimit(2)
            }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .background {
            if theme.blur && !reduceTransparency && !solid {
                ZStack {
                    VisualEffect(cornerRadius: radius, appearance: theme.appearance)
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color(theme.panel))
                }
            } else {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(reduceTransparency || solid ? theme.panel.opaque : theme.panel))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color(theme.line)))
        .shadow(color: .black.opacity(theme.blur ? 0.18 : 0.35), radius: 18, y: 10)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible || reduceMotion ? 1 : 0.97)
        .animation(.easeOut(duration: 0.22).delay(Double(index) * 0.03), value: isVisible)
    }

    @ViewBuilder private var content: some View {
        switch state?.content {
        case .rows(let rows):
            RowsView(content: rows, theme: theme)
        case .text(let text):
            TextOutputView(text: text, theme: theme)
        case .tail(let text):
            TextOutputView(text: text, tail: true, theme: theme)
        case .chart(let content):
            ChartView(content: content, size: tile.size, theme: theme)
        case .meters(let content):
            MetersView(content: content, size: tile.size, theme: theme)
        case .grid(let content):
            GridView(content: content, size: tile.size, theme: theme)
        case .timeline(let content):
            TimelineContentView(content: content, size: tile.size, theme: theme)
        case .stats(let content):
            StatsView(content: content, size: tile.size, theme: theme)
        case .markdown(let content):
            MarkdownView(content: content, size: tile.size, theme: theme)
        case .keyvalue(let content):
            KeyValueView(content: content, size: tile.size, theme: theme)
        case .table(let content):
            TableView(content: content, size: tile.size, theme: theme)
        case .feed(let content):
            FeedView(content: content, size: tile.size, theme: theme)
        case .checklist(let content):
            ChecklistView(content: content, size: tile.size, theme: theme)
        case nil:
            if state?.error == nil {
                Text("Loading…").font(.system(size: 11.5)).foregroundStyle(Color(theme.tertiaryText))
            }
        }
    }
}

/// The content's frame, widened by how far it may bleed into the tile's padding.
private struct BleedClip: Shape {
    let bleed: TileBleed

    func path(in rect: CGRect) -> Path {
        Path(CGRect(
            x: rect.minX - bleed.horizontal,
            y: rect.minY,
            width: rect.width + bleed.horizontal * 2,
            height: rect.height + bleed.bottom
        ))
    }
}
