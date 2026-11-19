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
