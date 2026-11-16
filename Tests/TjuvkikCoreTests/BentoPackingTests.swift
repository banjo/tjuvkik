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
