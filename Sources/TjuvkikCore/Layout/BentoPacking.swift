/// Tile sizes on the 4×3 Bento grid.
public enum TileSize: String, CaseIterable, Sendable {
    case s, m, l, xl

    public var columns: Int {
        switch self {
        case .s: 1
        case .m, .l, .xl: 2
        }
    }

    public var rows: Int {
        switch self {
        case .s, .m: 1
        case .l: 2
        case .xl: 3
        }
    }
}

public struct GridSlot: Equatable, Sendable {
    public var column: Int
    public var row: Int
    public var columns: Int
    public var rows: Int
}

/// Dense packing: each tile, in order, takes the first free spot (row by row) it fits in.
public enum BentoPacking {
    public static let columns = 4
    public static let rows = 3

    /// One slot per tile, nil for tiles that don't fit.
    public static func pack(_ sizes: [TileSize]) -> [GridSlot?] {
        var taken = Array(repeating: Array(repeating: false, count: columns), count: rows)

        func fits(_ size: TileSize, column: Int, row: Int) -> Bool {
            guard column + size.columns <= columns, row + size.rows <= rows else { return false }
            for r in row..<row + size.rows {
                for c in column..<column + size.columns where taken[r][c] { return false }
            }
            return true
        }

        return sizes.map { size in
            for row in 0..<rows {
                for column in 0..<columns where fits(size, column: column, row: row) {
                    for r in row..<row + size.rows {
                        for c in column..<column + size.columns { taken[r][c] = true }
                    }
                    return GridSlot(column: column, row: row, columns: size.columns, rows: size.rows)
                }
            }
            return nil
        }
    }
}
