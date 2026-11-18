import CoreGraphics
import Testing
@testable import TjuvkikCore

struct FocusNavigationTests {
    typealias Target = FocusNavigation.Target

    // Two tiles side by side, 100 wide: three rows on the left, two on the right a bit lower.
    let targets = [
        Target(frame: CGRect(x: 0, y: 0, width: 100, height: 20), tile: "a"),
        Target(frame: CGRect(x: 0, y: 20, width: 100, height: 20), tile: "a"),
        Target(frame: CGRect(x: 0, y: 40, width: 100, height: 20), tile: "a", urgency: 1),
        Target(frame: CGRect(x: 110, y: 30, width: 100, height: 20), tile: "b"),
        Target(frame: CGRect(x: 110, y: 48, width: 100, height: 20), tile: "b", urgency: 2),
        // A tile below both, without rows.
        Target(frame: CGRect(x: 0, y: 100, width: 210, height: 80), tile: "c"),
    ]

    @Test func movesWithinATile() {
        #expect(FocusNavigation.move(from: 0, .down, in: targets) == 1)
        #expect(FocusNavigation.move(from: 1, .up, in: targets) == 0)
        #expect(FocusNavigation.move(from: 0, .up, in: targets) == nil)
    }

    @Test func movesSidewaysToTheNearestHeight() {
        #expect(FocusNavigation.move(from: 0, .right, in: targets) == 3)
        #expect(FocusNavigation.move(from: 2, .right, in: targets) == 4)
        #expect(FocusNavigation.move(from: 4, .left, in: targets) == 2)
        #expect(FocusNavigation.move(from: 3, .right, in: targets) == nil)
    }

    @Test func movesDownIntoATileWithoutRows() {
        #expect(FocusNavigation.move(from: 2, .down, in: targets) == 5)
        #expect(FocusNavigation.move(from: 4, .down, in: targets) == 5)
        // The nearest above, whichever tile it's in.
        #expect(FocusNavigation.move(from: 5, .up, in: targets) == 4)
    }

    @Test func initialPicksUrgentRowsFirst() {
        #expect(FocusNavigation.initial(targets, focusTiles: []) == 4)
        #expect(FocusNavigation.initial(targets, focusTiles: ["a"]) == 2)
        #expect(FocusNavigation.initial(targets, focusTiles: ["c"]) == 4)
        let calm = targets.map { Target(frame: $0.frame, tile: $0.tile) }
        #expect(FocusNavigation.initial(calm, focusTiles: ["c"]) == 5)
        #expect(FocusNavigation.initial(calm, focusTiles: []) == 0)
        #expect(FocusNavigation.initial([], focusTiles: []) == nil)
    }
}
