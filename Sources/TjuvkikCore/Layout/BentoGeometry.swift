import CoreGraphics

/// Where tiles sit on the board, in points: the board is inset by `inset`, and cells are
/// separated by `gap`.
public enum BentoGeometry {
    public static let gap: CGFloat = 10
    public static let inset: CGFloat = 10
    /// The board at its largest, as the framed glance draws it on a big enough screen.
    public static let board = CGSize(width: 1080, height: 580)

    /// One cell's size on a board of `size`, inside its inset.
    public static func cell(in size: CGSize) -> CGSize {
        let inner = CGSize(width: size.width - inset * 2, height: size.height - inset * 2)
        return CGSize(
            width: (inner.width - gap * CGFloat(BentoPacking.columns - 1)) / CGFloat(BentoPacking.columns),
            height: (inner.height - gap * CGFloat(BentoPacking.rows - 1)) / CGFloat(BentoPacking.rows)
        )
    }

    /// A tile's size: its cells and the gaps between them.
    public static func size(columns: Int, rows: Int, cell: CGSize) -> CGSize {
        CGSize(
            width: cell.width * CGFloat(columns) + gap * CGFloat(columns - 1),
            height: cell.height * CGFloat(rows) + gap * CGFloat(rows - 1)
        )
    }

    /// A tile of `size` on the largest board.
    public static func size(of size: TileSize) -> CGSize {
        self.size(columns: size.columns, rows: size.rows, cell: cell(in: board))
    }
}
