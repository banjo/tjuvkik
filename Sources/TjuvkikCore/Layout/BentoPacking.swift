import Foundation

/// A tile's size on the Bento grid in cells, columns x rows, like `"2x1"`, `"3x1"` for a wide
/// strip or `"1x2"` for a tall one.
public struct TileSize: Hashable, Sendable, CustomStringConvertible {
    public var columns: Int
    public var rows: Int

    public static let s = TileSize(columns: 1, rows: 1)
    public static let m = TileSize(columns: 2, rows: 1)
    public static let l = TileSize(columns: 2, rows: 2)
    public static let xl = TileSize(columns: 2, rows: 3)

    /// The names sizes had before they were columns x rows. Still read, so older configs work.
    public static let aliases: [(name: String, size: TileSize)] = [("s", .s), ("m", .m), ("l", .l), ("xl", .xl)]
    public static let columnRange = 1...BoardGrid.columnRange.upperBound
    public static let rowRange = 1...BoardGrid.rowRange.upperBound
    /// What a size can be written as, for messages.
    public static let expected = "columns x rows, like 2x1"

    public init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }

    /// `"3x1"` / `"3×1"` in range, or an alias like `"m"`.
    public init?(rawValue text: String) {
        let text = text.trimmingCharacters(in: .whitespaces).lowercased()
        if let alias = Self.aliases.first(where: { $0.name == text }) {
            self = alias.size
            return
        }
        let parts = text.split(whereSeparator: { $0 == "x" || $0 == "×" })
        guard parts.count == 2, let columns = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let rows = Int(parts[1].trimmingCharacters(in: .whitespaces)),
              Self.columnRange.contains(columns), Self.rowRange.contains(rows) else { return nil }
        self.init(columns: columns, rows: rows)
    }

    /// `"3x1"`.
    public var rawValue: String { "\(columns)x\(rows)" }

    /// `"3×1"`, for people.
    public var label: String { "\(columns)×\(rows)" }

    public var description: String { rawValue }
}

/// How many cells the board has: `grid` in config.jsonc, like `"6x4"`.
public struct BoardGrid: Equatable, Sendable, CustomStringConvertible {
    public var columns: Int
    public var rows: Int

    public static let standard = BoardGrid(columns: 4, rows: 3)
    public static let columnRange = 2...8
    /// At least 3, so an xl tile fits.
    public static let rowRange = 3...6

    public init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }

    /// `"6x4"` or `"6×4"`, in range.
    public init?(_ text: String) {
        let parts = text.lowercased().split(whereSeparator: { $0 == "x" || $0 == "×" })
        guard parts.count == 2, let columns = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let rows = Int(parts[1].trimmingCharacters(in: .whitespaces)),
              Self.columnRange.contains(columns), Self.rowRange.contains(rows) else { return nil }
        self.init(columns: columns, rows: rows)
    }

    public var description: String { "\(columns)x\(rows)" }
}

public struct GridSlot: Equatable, Sendable {
    public var column: Int
    public var row: Int
    public var columns: Int
    public var rows: Int
}

/// Dense packing: each tile, in order, takes the first free spot (row by row) it fits in.
public enum BentoPacking {
    /// One slot per tile, nil for tiles that don't fit.
    public static func pack(_ sizes: [TileSize], grid: BoardGrid = .standard) -> [GridSlot?] {
        let columns = grid.columns, rows = grid.rows
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
