import SwiftUI
import TjuvkikCore

/// The tiles placed on the config's grid, filling the space it's given. The glance draws it, and the
/// settings window draws it small. `solid` draws tiles without the blur, which doesn't work
/// inside a scaled view.
struct BoardView: View {
    /// The coordinate space focus entries are reported in.
    static let space = "board"

    let config: Config
    let theme: Theme
    let states: [String: PanelStore.State]
    let isVisible: Bool
    var solid = false
    /// Outlined with the accent color.
    var selected: String?
    var onSelect: ((String) -> Void)?
    /// Set by the glance: what a row's click does, and each tile's right-click menu.
    var onAction: ((Tile, RowAction) -> Void)?
    var menu: ((Tile) -> TileMenu)?
    /// A click on the board but not on a tile.
    var onBackgroundClick: (() -> Void)?
    /// What the keyboard has focused, outlined.
    var focus: FocusEntry?
    /// The rows and tiles the keyboard can focus, as laid out.
    var onFocusEntries: (([FocusEntry]) -> Void)?
    /// Set by the glance: list items each tile skips at its top, what each has out of view, a
    /// tile's scroll by the trackpad or wheel, and its list items as laid out.
    var scroll: [String: Int] = [:]
    var scrollStates: [String: TileScrollState] = [:]
    var onScroll: ((String, Int) -> Void)?
    var onScrollItems: (([ScrollItem]) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            if let onBackgroundClick {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onBackgroundClick)
            }
            let board = theme.board
            let cell = BentoGeometry.cell(in: geometry.size, grid: config.grid, board: board)
            let gap = CGFloat(board.gap), inset = CGFloat(board.inset)
            ForEach(Array(config.tiles.enumerated()), id: \.offset) { index, tile in
                if let slot = tile.slot {
                    let size = BentoGeometry.size(columns: slot.columns, rows: slot.rows, cell: cell, board: board)
                    TileView(tile: tile, state: states[tile.id], theme: theme, index: index, isVisible: isVisible, solid: solid,
                             onAction: onAction.map { onAction in { onAction(tile, $0) } }, menu: menu?(tile),
                             scroll: scroll[tile.id] ?? 0, scrollState: scrollStates[tile.id],
                             onScroll: onScroll.map { onScroll in { onScroll(tile.id, $0) } })
                        .frame(width: size.width, height: size.height)
                        .overlay {
                            if selected == tile.id {
                                RoundedRectangle(cornerRadius: theme.radius + theme.z(3), style: .continuous)
                                    .strokeBorder(Color.accentColor, lineWidth: theme.z(6))
                                    .padding(-theme.z(6))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect?(tile.id) }
                        .allowsHitTesting(onSelect != nil || onAction != nil || menu != nil)
                        .position(
                            x: inset + (cell.width + gap) * CGFloat(slot.column) + size.width / 2,
                            y: inset + (cell.height + gap) * CGFloat(slot.row) + size.height / 2
                        )
                }
            }
            if let focus {
                let ring = theme.z(focus.action == nil ? 3 : 1.5)
                RoundedRectangle(cornerRadius: focus.radius + ring, style: .continuous)
                    .fill(focus.action == nil ? Color.clear : Color(theme.accent).opacity(0.12))
                    .strokeBorder(Color(theme.accent), lineWidth: ring)
                    .frame(width: focus.frame.width + ring * 2, height: focus.frame.height + ring * 2)
                    .position(x: focus.frame.midX, y: focus.frame.midY)
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: Self.space)
        .onPreferenceChange(FocusEntriesKey.self) { entries in
            MainActor.assumeIsolated { onFocusEntries?(entries) }
        }
        .onPreferenceChange(ScrollItemsKey.self) { items in
            MainActor.assumeIsolated { onScrollItems?(items) }
        }
        .environment(\.colorScheme, theme.appearance.colorScheme)
    }
}

/// A board drawn at the glance's full size and shrunk to the width it's given.
struct BoardMiniature: View {
    let config: Config
    let theme: Theme
    let states: [String: PanelStore.State]
    var selected: String?
    var onSelect: ((String) -> Void)?

    var body: some View {
        let full = BentoGeometry.board(config.grid, theme: theme)
        GeometryReader { geometry in
            let scale = geometry.size.width / full.width
            BoardView(config: config, theme: theme, states: states, isVisible: true, solid: true, selected: selected, onSelect: onSelect)
                .frame(width: full.width, height: full.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .aspectRatio(full.width / full.height, contentMode: .fit)
        .background(Color(theme.appearance == .dark ? RGBA(red: 0.16, green: 0.17, blue: 0.2) : RGBA(red: 0.86, green: 0.88, blue: 0.91)),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
