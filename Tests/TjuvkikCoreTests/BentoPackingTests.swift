import Testing
@testable import TjuvkikCore

struct BentoPackingTests {
    @Test func fillsDensely() {
        let slots = BentoPacking.pack([.xl, .s, .s, .s, .s, .m])
        #expect(slots == [
            GridSlot(column: 0, row: 0, columns: 2, rows: 3),
            GridSlot(column: 2, row: 0, columns: 1, rows: 1),
            GridSlot(column: 3, row: 0, columns: 1, rows: 1),
            GridSlot(column: 2, row: 1, columns: 1, rows: 1),
            GridSlot(column: 3, row: 1, columns: 1, rows: 1),
            GridSlot(column: 2, row: 2, columns: 2, rows: 1),
        ])
    }

    @Test func aWiderGridFitsMore() {
        let sizes: [TileSize] = [.xl, .xl, .l, .m]
        #expect(BentoPacking.pack(sizes).last == .some(nil))
        #expect(BentoPacking.pack(sizes, grid: BoardGrid(columns: 6, rows: 4)) == [
            GridSlot(column: 0, row: 0, columns: 2, rows: 3),
            GridSlot(column: 2, row: 0, columns: 2, rows: 3),
            GridSlot(column: 4, row: 0, columns: 2, rows: 2),
            GridSlot(column: 4, row: 2, columns: 2, rows: 1),
        ])
    }

    @Test func gridsAreReadFromText() {
        #expect(BoardGrid("6x4") == BoardGrid(columns: 6, rows: 4))
        #expect(BoardGrid("5×3") == BoardGrid(columns: 5, rows: 3))
        #expect(BoardGrid(" 4 x 3 ") == .standard)
        #expect(BoardGrid("4x2") == nil)
        #expect(BoardGrid("9x4") == nil)
        #expect(BoardGrid("big") == nil)
    }

    @Test func sizesAreReadFromText() {
        // The old names still read.
        #expect(TileSize(rawValue: "m") == .m)
        #expect(TileSize(rawValue: " XL ") == .xl)
        #expect(TileSize(rawValue: "3x1") == TileSize(columns: 3, rows: 1))
        #expect(TileSize(rawValue: "1 × 2") == TileSize(columns: 1, rows: 2))
        #expect(TileSize(rawValue: "2x2") == .l)
        #expect(TileSize(rawValue: "0x1") == nil)
        #expect(TileSize(rawValue: "9x1") == nil)
        #expect(TileSize(rawValue: "huge") == nil)
        #expect(TileSize(columns: 2, rows: 1).rawValue == "2x1")
        #expect(TileSize(columns: 4, rows: 1).rawValue == "4x1")
    }

    @Test func wideAndTallTilesPack() {
        let wide = TileSize(columns: 4, rows: 1), tall = TileSize(columns: 1, rows: 2)
        #expect(BentoPacking.pack([wide, tall, .s, .s, .s, wide]) == [
            GridSlot(column: 0, row: 0, columns: 4, rows: 1),
            GridSlot(column: 0, row: 1, columns: 1, rows: 2),
            GridSlot(column: 1, row: 1, columns: 1, rows: 1),
            GridSlot(column: 2, row: 1, columns: 1, rows: 1),
            GridSlot(column: 3, row: 1, columns: 1, rows: 1),
            nil,
        ])
        #expect(BentoPacking.pack([TileSize(columns: 5, rows: 1)]) == [nil])
    }

    @Test func smallTileFillsAGapLeftBehind() {
        let slots = BentoPacking.pack([.s, .l, .m, .s])
        #expect(slots == [
            GridSlot(column: 0, row: 0, columns: 1, rows: 1),
            GridSlot(column: 1, row: 0, columns: 2, rows: 2),
            GridSlot(column: 0, row: 2, columns: 2, rows: 1),
            GridSlot(column: 3, row: 0, columns: 1, rows: 1),
        ])
    }
}
