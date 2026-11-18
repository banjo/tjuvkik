import CoreGraphics

/// Moving a keyboard focus around the glance: between clickable rows, and tiles without any.
public enum FocusNavigation {
    public enum Direction: Sendable { case up, down, left, right }

    /// Something that can have the focus, in the board's coordinates (y grows downwards).
    public struct Target: Equatable, Sendable {
        public var frame: CGRect
        public var tile: String
        /// 2 for an error row, 1 for a warning, 0 otherwise.
        public var urgency: Int

        public init(frame: CGRect, tile: String, urgency: Int = 0) {
            self.frame = frame
            self.tile = tile
            self.urgency = urgency
        }
    }

    /// What to focus when the glance opens: the most urgent row in a focused tile, then the most
    /// urgent anywhere, then a focused tile's first target, then the first target. `targets` are
    /// in reading order; `focusTiles` in config order.
    public static func initial(_ targets: [Target], focusTiles: [String]) -> Int? {
        guard !targets.isEmpty else { return nil }
        let urgent = targets.indices.filter { targets[$0].urgency > 0 }
        func mostUrgent(_ indices: [Int]) -> Int? {
            indices.first { targets[$0].urgency == 2 } ?? indices.first
        }
        for tile in focusTiles {
            if let index = mostUrgent(urgent.filter { targets[$0].tile == tile }) { return index }
        }
        if let index = mostUrgent(urgent) { return index }
        for tile in focusTiles {
            if let index = targets.firstIndex(where: { $0.tile == tile }) { return index }
        }
        return 0
    }

    /// The nearest target in `direction` from `current`, or nil at the edge. Distance along the
    /// direction counts less than drifting sideways, so left and right keep about the same height
    /// and up and down the same column.
    public static func move(from current: Int, _ direction: Direction, in targets: [Target]) -> Int? {
        guard targets.indices.contains(current) else { return nil }
        let from = targets[current].frame
        var best: (index: Int, score: CGFloat)?
        for (index, target) in targets.enumerated() where index != current {
            guard let score = score(from: from, to: target.frame, direction) else { continue }
            if best == nil || score < best!.score { best = (index, score) }
        }
        return best?.index
    }

    private static func score(from: CGRect, to: CGRect, _ direction: Direction) -> CGFloat? {
        let along: CGFloat, gap: CGFloat, centers: CGFloat
        switch direction {
        case .right, .left:
            guard direction == .right ? to.minX >= from.midX : to.maxX <= from.midX else { return nil }
            along = max(0, direction == .right ? to.minX - from.maxX : from.minX - to.maxX)
            gap = max(0, max(from.minY, to.minY) - min(from.maxY, to.maxY))
            centers = abs(to.midY - from.midY)
        case .down, .up:
            guard direction == .down ? to.minY >= from.midY : to.maxY <= from.midY else { return nil }
            along = max(0, direction == .down ? to.minY - from.maxY : from.minY - to.maxY)
            gap = max(0, max(from.minX, to.minX) - min(from.maxX, to.maxX))
            centers = abs(to.midX - from.midX)
        }
        return along + gap * 3 + centers * 0.1
    }
}
