import AppKit
import SwiftUI
import TjuvkikCore

/// The Framed Bento board: tiles on a 4×3 grid, placed from the config.
struct GlanceView: View {
    let model: GlanceModel
    let store: ConfigStore
    let onFocusEntries: ([FocusEntry]) -> Void
    let panels: PanelStore
    /// A click between the tiles.
    let onBackgroundClick: () -> Void
    let onAction: (Tile, RowAction) -> Void
    let menu: (Tile) -> TileMenu

    var body: some View {
        let config = store.config
        BoardView(config: config, theme: config.theme(dark: model.systemIsDark), states: panels.states, isVisible: model.isVisible,
                  onAction: onAction, menu: menu, onBackgroundClick: onBackgroundClick,
                  focus: model.showsFocus ? model.focused : nil, onFocusEntries: onFocusEntries)
    }
}

/// A tile's right-click menu in the glance.
struct TileMenu {
    var runNow: () -> Void = {}
    var openConfig: () -> Void = {}
    var showInFinder: () -> Void = {}
    var openSettings: () -> Void = {}
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
    /// Set by the glance, where rows with a `url` or `command` click.
    var onAction: ((RowAction) -> Void)?
    var menu: TileMenu?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let radius = CGFloat(theme.radius)
        let padding = CGFloat(theme.tile.padding)
        // Content may draw into the padding at the sides, and at the bottom unless an error is
        // shown there.
        let bleed = TileBleed(horizontal: padding, bottom: state?.error == nil ? padding : 0)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(tile.title)
                    .font(theme.font(12, weight: .semibold))
                    .foregroundStyle(Color(theme.secondaryText))
                    .textCase(theme.tile.uppercaseTitle ? .uppercase : nil)
                if theme.tile.showKind {
                    Text(state?.content?.type?.rawValue ?? tile.typeName)
                        .font(theme.font(9.5, weight: .medium, mono: true))
                        .foregroundStyle(Color(theme.tertiaryText))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color(theme.well), in: RoundedRectangle(cornerRadius: 4))
                }
                Spacer()
                if state?.error != nil && state?.content != nil {
                    Text("stale").font(theme.font(10.5, weight: .medium)).foregroundStyle(Color(theme.warning))
                } else if let state, state.running, tile.mode == .interval, state.content != nil,
                          let updated = state.updated, Date().timeIntervalSince(updated) >= tile.every {
                    Text("updating…")
                        .font(theme.font(10.5))
                        .foregroundStyle(Color(theme.tertiaryText))
                } else if theme.tile.showInterval {
                    Text(tile.mode == .stream ? "live" : "every \(Duration.seconds(tile.every).formatted(.units(allowed: [.days, .hours, .minutes, .seconds], width: .narrow)))")
                        .font(theme.font(10.5))
                        .foregroundStyle(Color(theme.tertiaryText))
                }
            }
            content
                .environment(\.tileBleed, bleed)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipShape(BleedClip(bleed: bleed))
            if let error = state?.error {
                Text(error)
                    .font(theme.font(10.5))
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
                    VisualEffect(cornerRadius: radius, appearance: theme.appearance, material: theme.material)
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color(theme.panel))
                }
            } else {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(reduceTransparency || solid ? theme.panel.opaque : theme.panel))
            }
        }
        .overlay {
            if theme.tile.border > 0 {
                RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color(theme.line), lineWidth: theme.tile.border)
            }
        }
        .shadow(
            color: theme.tile.shadow ? .black.opacity(theme.blur ? 0.18 : 0.35) : .clear,
            radius: theme.tile.shadow ? 18 : 0, y: theme.tile.shadow ? 10 : 0
        )
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible || reduceMotion ? 1 : 0.97)
        .animation(.easeOut(duration: 0.22).delay(Double(index) * 0.03), value: isVisible)
        .environment(\.performRow, onAction)
        .environment(\.focusTile, tile.id)
        .modifier(TileFocusEntry(tile: tile.id, radius: radius, active: onAction != nil))
        .tileMenu(menu)
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
                Text("Loading…").font(theme.font(11.5)).foregroundStyle(Color(theme.tertiaryText))
            }
        }
    }
}

/// The whole tile as a focus target, reported only in the glance.
private struct TileFocusEntry: ViewModifier {
    let tile: String
    let radius: CGFloat
    let active: Bool

    func body(content: Content) -> some View {
        if active { content.focusEntry(tile: tile, action: nil, radius: radius) } else { content }
    }
}

private extension View {
    @ViewBuilder func tileMenu(_ menu: TileMenu?) -> some View {
        if let menu {
            contextMenu {
                Button("Run Now", action: menu.runNow)
                Button("Open panel.jsonc", action: menu.openConfig)
                Button("Show in Finder", action: menu.showInFinder)
                Divider()
                Button("Settings…", action: menu.openSettings)
            }
        } else {
            self
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
