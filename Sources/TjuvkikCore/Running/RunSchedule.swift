import Foundation

/// When an interval panel runs: on `every` while the glance is open, and on its `background`
/// while it's closed, unless background runs are paused.
public enum RunSchedule {
    /// Seconds between runs right now, or nil when the panel shouldn't run on its own.
    public static func interval(for tile: Tile, glanceOpen: Bool, paused: Bool) -> Double? {
        if glanceOpen { return tile.every }
        if paused { return nil }
        switch tile.background {
        case .same: return tile.every
        case .every(let seconds): return seconds
        case .off: return nil
        }
    }

    public static func isDue(lastRun: Date?, now: Date, interval: Double?) -> Bool {
        guard let interval else { return false }
        guard let lastRun else { return true }
        return now.timeIntervalSince(lastRun) >= interval
    }
}
