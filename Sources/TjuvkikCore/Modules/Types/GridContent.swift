import Foundation

/// Many things at once, a colored cell each:
/// `{ "grid": { "rows": [{ "label": "auth", "value": "100%", "cells": ["success", "warning"] }] } }`.
/// A single cell shows the worst count and a dot per row, a tile one row high a chip per row, and
/// a taller one a row each with its cells as history. `levels` instead of rows gives a heatmap, like GitHub contributions.
public struct GridContent: Equatable, Sendable, Decodable {
    /// One cell: a tone, or a level from 0 to 4 for a heatmap.
    public enum Cell: Equatable, Sendable, Decodable {
        case tone(Tone)
        case level(Int)

        /// A number, or a number written as text, is a level; anything else a tone. `null` is empty.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .tone(.normal)
            } else if let number = try? container.decode(Double.self) {
                self = .level(GridContent.level(number))
            } else {
                let text = try container.decode(String.self)
                if let number = Double(text) {
                    self = .level(GridContent.level(number))
                } else {
                    self = .tone(Tone(rawValue: text) ?? .normal)
                }
            }
        }
    }

    public struct Row: Equatable, Sendable, Decodable {
        public var label: String
        /// Right of the cells at l, in the chip at m: "99.2%", "failed".
        public var value: String?
        /// The row's state. Without one, its last tone cell.
        public var tone: Tone?
        /// History, oldest first.
        public var cells: [Cell]

        public init(label: String, value: String? = nil, tone: Tone? = nil, cells: [Cell] = []) {
            self.label = label
            self.value = value
            self.tone = tone
            self.cells = cells
        }

        private enum CodingKeys: String, CodingKey { case label, value, tone, cells }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            label = try container.decodeText(forKey: .label)
            value = try container.decodeTextIfPresent(forKey: .value)
            tone = try container.decodeIfPresent(Tone.self, forKey: .tone)
            cells = try container.decodeIfPresent([Cell].self, forKey: .cells) ?? []
        }

        /// The row's state: its tone, else its last tone cell, else normal.
        public var status: Tone {
            if let tone { return tone }
            for cell in cells.reversed() {
                if case .tone(let tone) = cell { return tone }
            }
            return .normal
        }
    }

    public struct LegendEntry: Equatable, Sendable {
        public var tone: Tone
        public var text: String

        public init(tone: Tone, text: String) {
            self.tone = tone
            self.text = text
        }
    }

    public struct ToneCount: Equatable, Sendable {
        public var tone: Tone
        public var count: Int

        public init(tone: Tone, count: Int) {
            self.tone = tone
            self.count = count
        }
    }

    /// What an s tile shows big: "1 down", then "1 degraded, 10 up".
    public struct Headline: Equatable, Sendable {
        public var value: String
        public var label: String?
        public var tone: Tone

        public init(value: String, label: String? = nil, tone: Tone) {
            self.value = value
            self.label = label
            self.tone = tone
        }
    }

    public var rows: [Row]
    /// Under the cells at l, spread out: ["24h ago", "12h", "now"].
    public var axis: [String]?
    /// What each tone means, mildest first.
    public var legend: [LegendEntry]
    /// A line at the bottom: "checked every 5m", "214 commits in 20 weeks".
    public var footer: String?
    /// Replace the s tile's computed headline.
    public var value: String?
    public var label: String?
    /// The headline's color, and the heatmap's (accent by default).
    public var tone: Tone?
    /// A heatmap: columns of levels from 0 to 4, oldest first, each top to bottom.
    public var levels: [[Int]]?
    public var extras: PanelExtras

    public init(rows: [Row] = [], axis: [String]? = nil, legend: [LegendEntry] = [], footer: String? = nil,
                value: String? = nil, label: String? = nil, tone: Tone? = nil, levels: [[Int]]? = nil,
                extras: PanelExtras = PanelExtras()) {
        self.rows = rows
        self.axis = axis
        self.legend = legend
        self.footer = footer
        self.value = value
        self.label = label
        self.tone = tone
        self.levels = levels
        self.extras = extras
    }

    private enum OuterKeys: String, CodingKey { case grid }
    private enum CodingKeys: String, CodingKey { case rows, axis, legend, footer, value, label, tone, levels, height }

    public init(from decoder: any Decoder) throws {
        let grid = try decoder.container(keyedBy: OuterKeys.self).nestedContainer(keyedBy: CodingKeys.self, forKey: .grid)
        rows = try grid.contains(.rows) ? grid.decodeOneOrMany(Row.self, forKey: .rows) : []
        axis = try grid.decodeIfPresent([String].self, forKey: .axis)
        legend = GridContent.ordered(try grid.decodeIfPresent([String: String].self, forKey: .legend) ?? [:])
        footer = try grid.decodeTextIfPresent(forKey: .footer)
        value = try grid.decodeTextIfPresent(forKey: .value)
        label = try grid.decodeTextIfPresent(forKey: .label)
        tone = try grid.decodeIfPresent(Tone.self, forKey: .tone)
        if grid.contains(.levels) {
            if let columns = try? grid.decode([[Level]].self, forKey: .levels) {
                levels = columns.map { $0.map(\.value) }
            } else {
                let height = try grid.decodeIfPresent(Double.self, forKey: .height).map { $0.isFinite ? Int(min(max($0.rounded(), 1), 1000)) : 7 } ?? 7
                levels = GridContent.columns(try grid.decode([Level].self, forKey: .levels).map(\.value), height: height)
            }
        } else if !grid.contains(.rows) {
            throw DecodingError.keyNotFound(CodingKeys.rows, .init(codingPath: grid.codingPath, debugDescription: "grid needs rows or levels"))
        } else {
            levels = nil
        }
        extras = try PanelExtras(from: decoder)
    }

    // MARK: - Tones

    /// How bad a tone is: error over warning over info and accent over success over the rest.
    public static func severity(_ tone: Tone) -> Int {
        switch tone {
        case .error: 4
        case .warning: 3
        case .info, .accent: 2
        case .success: 1
        case .muted, .normal: 0
        }
    }

    /// The worst row's state, or nil without rows. Of two equally bad, the first.
    public var worst: Tone? {
        rows.map(\.status).max { GridContent.severity($0) < GridContent.severity($1) }
    }

    /// How many rows have each state, worst first; equally bad in the order they first appear.
    public var counts: [ToneCount] {
        var counts: [ToneCount] = []
        for status in rows.map(\.status) {
            if let index = counts.firstIndex(where: { $0.tone == status }) {
                counts[index].count += 1
            } else {
                counts.append(ToneCount(tone: status, count: 1))
            }
        }
        let order = counts.map(\.tone)
        return counts.sorted {
            let (a, b) = (GridContent.severity($0.tone), GridContent.severity($1.tone))
            return a != b ? a > b : order.firstIndex(of: $0.tone)! < order.firstIndex(of: $1.tone)!
        }
    }

    /// What a tone is called: the legend's text, else a plain word.
    public func word(for tone: Tone) -> String {
        if let entry = legend.first(where: { $0.tone == tone }) { return entry.text }
        return switch tone {
        case .error: "error"
        case .warning: "warning"
        case .info: "info"
        case .accent: "accent"
        case .success: "ok"
        case .muted: "muted"
        case .normal: "other"
        }
    }

    /// "1 down" and "1 degraded, 10 up"; "All up" when every row is fine. `value`, `label` and
    /// `tone` replace each part.
    public var headline: Headline {
        let counts = self.counts
        var computed = Headline(value: String(rows.count), tone: .normal)
        if let first = counts.first {
            let plain = first.tone == .normal && !legend.contains { $0.tone == .normal }
            if counts.count == 1, GridContent.severity(first.tone) <= 1 {
                computed = plain ? Headline(value: String(first.count), tone: .normal) : Headline(value: "All \(word(for: first.tone))", tone: first.tone)
            } else {
                let rest = counts.dropFirst().map { "\($0.count) \(word(for: $0.tone))" }.joined(separator: ", ")
                computed = Headline(value: plain ? String(first.count) : "\(first.count) \(word(for: first.tone))",
                                    label: rest.isEmpty ? nil : rest, tone: first.tone)
            }
        }
        return Headline(value: value ?? computed.value, label: label ?? computed.label, tone: tone ?? computed.tone)
    }

    // MARK: - Levels

    /// A heatmap cell's opacity: faint for 0, then stronger with each level.
    public static func opacity(level: Int) -> Double {
        let level = min(max(level, 0), 4)
        return level == 0 ? 0.06 : 0.18 + Double(level) * 0.2
    }

    /// Cells per heatmap column: the tallest column.
    public var levelHeight: Int {
        levels?.map(\.count).max() ?? 0
    }

    /// The newest `limit` heatmap columns, or all of them.
    public func heatmap(limit: Int? = nil) -> [[Int]] {
        guard let levels else { return [] }
        guard let limit else { return levels }
        return Array(levels.suffix(max(limit, 0)))
    }

    /// 0 to 4, rounded.
    static func level(_ number: Double) -> Int {
        guard number.isFinite else { return 0 }
        return Int(min(max(number.rounded(), 0), 4))
    }

    /// A flat list of levels cut into columns of `height`, top to bottom.
    static func columns(_ levels: [Int], height: Int) -> [[Int]] {
        let height = max(height, 1)
        return stride(from: 0, to: levels.count, by: height).map { Array(levels[$0..<min($0 + height, levels.count)]) }
    }

    /// Legend entries mildest first, as a key reads: up, degraded, down. Keys that aren't tones are left out.
    static func ordered(_ legend: [String: String]) -> [LegendEntry] {
        legend.compactMap { key, text in Tone(rawValue: key).map { LegendEntry(tone: $0, text: text) } }
            .sorted {
                let (a, b) = (severity($0.tone), severity($1.tone))
                return a != b ? a < b : Tone.allCases.firstIndex(of: $0.tone)! < Tone.allCases.firstIndex(of: $1.tone)!
            }
    }

    /// A heatmap level: a number or a number written as text, rounded into 0 to 4; anything else 0.
    private struct Level: Decodable {
        var value: Int

        init(from decoder: any Decoder) throws {
            if case .level(let level) = try Cell(from: decoder) {
                value = level
            } else {
                value = 0
            }
        }
    }
}
