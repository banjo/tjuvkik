import CoreGraphics

/// Where tiles sit on the board, in points: the board is inset by the theme's `board.inset`, and
/// cells are separated by its `board.gap`. A cell has the same size on every grid; a bigger grid
/// makes a bigger board, and the zoom draws all of it bigger.
public enum BentoGeometry {
    /// One cell at zoom 1: what the panel types are drawn for.
    public static let cell = CGSize(width: 257.5, height: 180)

    /// The board for `grid`: its cells at the theme's zoom, the gaps between them and its inset.
    public static func board(_ grid: BoardGrid, theme: Theme) -> CGSize {
        let inset = CGFloat(theme.board.inset)
        let cells = size(columns: grid.columns, rows: grid.rows,
                         cell: CGSize(width: theme.z(cell.width), height: theme.z(cell.height)), board: theme.board)
        return CGSize(width: cells.width + inset * 2, height: cells.height + inset * 2)
    }

    /// One cell's size on a board of `size`, inside its inset.
    public static func cell(in size: CGSize, grid: BoardGrid, board: Theme.Board = Theme.Board()) -> CGSize {
        let inset = CGFloat(board.inset), gap = CGFloat(board.gap)
        let inner = CGSize(width: size.width - inset * 2, height: size.height - inset * 2)
        return CGSize(
            width: (inner.width - gap * CGFloat(grid.columns - 1)) / CGFloat(grid.columns),
            height: (inner.height - gap * CGFloat(grid.rows - 1)) / CGFloat(grid.rows)
        )
    }

    /// A tile's size: its cells and the gaps between them.
    public static func size(columns: Int, rows: Int, cell: CGSize, board: Theme.Board = Theme.Board()) -> CGSize {
        let gap = CGFloat(board.gap)
        return CGSize(
            width: cell.width * CGFloat(columns) + gap * CGFloat(columns - 1),
            height: cell.height * CGFloat(rows) + gap * CGFloat(rows - 1)
        )
    }

    /// A tile of `size` at zoom 1.
    public static func size(of size: TileSize, board: Theme.Board = Theme.Board()) -> CGSize {
        self.size(columns: size.columns, rows: size.rows, cell: cell, board: board)
    }
}
