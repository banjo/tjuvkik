import Foundation
import Testing
@testable import TjuvkikCore

struct RunScheduleTests {
    /// A tile from a config directory, with `every` and `background` set as the test wants them.
    private func tile(every: Double, background: Tile.Background) throws -> Tile {
        var tile = try load([
            "config.json": #"{ "panels": [{ "panel": "x" }] }"#,
            "panels/x/panel.json": #"{ "type": "cli", "command": "ls" }"#,
        ]).config.tiles[0]
        tile.every = every
        tile.background = background
        return tile
    }

    @Test func openGlanceUsesEvery() throws {
        for background in [Tile.Background.same, .every(300), .off] {
            let tile = try tile(every: 60, background: background)
            #expect(RunSchedule.interval(for: tile, glanceOpen: true, paused: false) == 60)
            #expect(RunSchedule.interval(for: tile, glanceOpen: true, paused: true) == 60)
        }
    }

    @Test func closedGlanceUsesBackground() throws {
        #expect(RunSchedule.interval(for: try tile(every: 60, background: .same), glanceOpen: false, paused: false) == 60)
        #expect(RunSchedule.interval(for: try tile(every: 60, background: .every(300)), glanceOpen: false, paused: false) == 300)
        #expect(RunSchedule.interval(for: try tile(every: 60, background: .off), glanceOpen: false, paused: false) == nil)
    }

    @Test func pausedStopsBackgroundRuns() throws {
        for background in [Tile.Background.same, .every(300), .off] {
            let tile = try tile(every: 60, background: background)
            #expect(RunSchedule.interval(for: tile, glanceOpen: false, paused: true) == nil)
        }
    }

    @Test func isDue() {
        let now = Date()
        #expect(!RunSchedule.isDue(lastRun: nil, now: now, interval: nil))
        #expect(RunSchedule.isDue(lastRun: nil, now: now, interval: 60))
        #expect(!RunSchedule.isDue(lastRun: now.addingTimeInterval(-59), now: now, interval: 60))
        #expect(RunSchedule.isDue(lastRun: now.addingTimeInterval(-60), now: now, interval: 60))
    }
}
