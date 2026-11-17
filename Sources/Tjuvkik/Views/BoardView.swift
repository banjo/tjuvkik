import SwiftUI
import TjuvkikCore

/// The tiles placed on the 4×3 grid, filling the space it's given. The glance draws it, and the
/// settings window draws it small. `solid` draws tiles without the blur, which doesn't work
/// inside a scaled view.
struct BoardView: View {
    let config: Config
    let theme: Theme
    let states: [String: PanelStore.State]
    let isVisible: Bool
    var solid = false
    /// Outlined with the accent color.
    var selected: String?
    var onSelect: ((String) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let board = theme.board
            let cell = BentoGeometry.cell(in: geometry.size, board: board)
            let gap = CGFloat(board.gap), inset = CGFloat(board.inset)
            ForEach(Array(config.tiles.enumerated()), id: \.offset) { index, tile in
                if let slot = tile.slot {
                    let size = BentoGeometry.size(columns: slot.columns, rows: slot.rows, cell: cell, board: board)
                    TileView(tile: tile, state: states[tile.id], theme: theme, index: index, isVisible: isVisible, solid: solid)
                        .frame(width: size.width, height: size.height)
                        .overlay {
                            if selected == tile.id {
                                RoundedRectangle(cornerRadius: theme.radius + 3, style: .continuous)
                                    .strokeBorder(Color.accentColor, lineWidth: 6)
                                    .padding(-6)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect?(tile.id) }
                        .allowsHitTesting(onSelect != nil)
                        .position(
                            x: inset + (cell.width + gap) * CGFloat(slot.column) + size.width / 2,
                            y: inset + (cell.height + gap) * CGFloat(slot.row) + size.height / 2
                        )
                }
            }
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
        let full = BentoGeometry.board
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
