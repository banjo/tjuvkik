import Foundation

/// The same fields for every row: `{ "columns": [{ "title": "Pod" }], "rows": [{ "cells": ["api-1"] }] }`.
/// Columns that don't fit are dropped from the right; `priority` keeps a column longer.
public struct TableContent: Equatable, Sendable, Decodable {
    public struct Column: Equatable, Sendable, Decodable {
        public enum Align: String, Equatable, Sendable, Decodable {
            case left, right, center

            /// Unknown alignments read as left.
            public init(from decoder: any Decoder) throws {
                self = Align(rawValue: try decoder.singleValueContainer().decode(String.self).lowercased()) ?? .left
            }
        }

        public var title: String
        /// Monospaced cells, for IDs, versions and ports.
        public var mono: Bool
        public var align: Align
        /// Higher keeps the column longer when the tile is too narrow for all of them. 0 by default.
        public var priority: Int
        /// The share of the table's width, 0 to 1, from `"38%"`, `38` or `0.38`. Nil shares what's left.
        public var width: Double?

        public init(title: String, mono: Bool = false, align: Align = .left, priority: Int = 0, width: Double? = nil) {
            self.title = title
            self.mono = mono
            self.align = align
            self.priority = priority
            self.width = width
        }

        private enum CodingKeys: String, CodingKey { case title, mono, align, priority, width }

        /// An object, or just the title: `"Pod"`.
        public init(from decoder: any Decoder) throws {
            if let title = try? decoder.singleValueContainer().decode(String.self) {
                self.init(title: title)
                return
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                title: try container.decodeTextIfPresent(forKey: .title) ?? "",
                mono: try container.decodeIfPresent(Bool.self, forKey: .mono) ?? false,
                align: try container.decodeIfPresent(Align.self, forKey: .align) ?? .left,
                priority: try container.decodeTextIfPresent(forKey: .priority).flatMap { Double($0) }.map { Int(max(min($0, 1_000), -1_000)) } ?? 0,
                width: try container.decodeTextIfPresent(forKey: .width).flatMap { Column.share($0) }
            )
        }

        /// `"38%"`, `38` or `0.38` as 0.38, clamped to 1–100%. Nil for anything else.
        static func share(_ text: String) -> Double? {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            let isPercent = trimmed.hasSuffix("%")
            let number = isPercent ? String(trimmed.dropLast()) : trimmed
            guard var percent = Double(number.trimmingCharacters(in: .whitespaces)), percent > 0 else { return nil }
            if !isPercent && percent < 1 { percent *= 100 }
            return min(max(percent, 1), 100) / 100
        }
    }

    public struct Cell: Equatable, Sendable, Decodable {
        public var text: String
        public var tone: Tone?
        /// A dot in the cell's tone before the text, for a status.
        public var dot: Bool
        /// Shown in the secondary color, for what matters less.
        public var dim: Bool

        public init(_ text: String, tone: Tone? = nil, dot: Bool = false, dim: Bool = false) {
            self.text = text
            self.tone = tone
            self.dot = dot
            self.dim = dim
        }

        private enum CodingKeys: String, CodingKey { case text, tone, dot, dim }

        /// Text, a number, null (empty), or an object.
        public init(from decoder: any Decoder) throws {
            if let single = try? decoder.singleValueContainer() {
                if single.decodeNil() {
                    self.init("")
                    return
                }
                if let number = try? single.decode(Double.self) {
                    self.init(number.text)
                    return
                }
                if let text = try? single.decode(String.self) {
                    self.init(text)
                    return
                }
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                try container.decodeTextIfPresent(forKey: .text) ?? "",
                tone: try container.decodeIfPresent(Tone.self, forKey: .tone),
                dot: try container.decodeIfPresent(Bool.self, forKey: .dot) ?? false,
                dim: try container.decodeIfPresent(Bool.self, forKey: .dim) ?? false
            )
        }
    }

    public struct Row: Equatable, Sendable, Decodable {
        /// In column order. Missing cells show empty; extra cells are ignored.
        public var cells: [Cell]
        /// The row's tint, for what needs attention. `true` is the error tone.
        public var highlight: Tone?
        /// Opened when the row is picked.
        public var url: String?
        /// Run when the row is picked, in the panel's folder. Wins over `url`.
        public var command: String?
        /// `actionTitle` and `actions`, for the glance's keyboard.
        public var actions = RowActions()

        public init(cells: [Cell], highlight: Tone? = nil, url: String? = nil, command: String? = nil) {
            self.cells = cells
            self.highlight = highlight
            self.url = url
            self.command = command
        }

        private enum CodingKeys: String, CodingKey { case cells, highlight, url, command }

        /// An object, or just the cells: `["api-1", "Running"]`.
        public init(from decoder: any Decoder) throws {
            if let cells = try? decoder.singleValueContainer().decode([Cell].self) {
                self.init(cells: cells)
                return
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let cells = try container.decode([Cell].self, forKey: .cells)
            let highlight: Tone?
            if let on = try? container.decodeIfPresent(Bool.self, forKey: .highlight) {
                highlight = on ? .error : nil
            } else {
                highlight = try container.decodeIfPresent(Tone.self, forKey: .highlight)
            }
            self.init(
                cells: cells,
                highlight: highlight,
                url: try container.decodeIfPresent(String.self, forKey: .url),
                command: try container.decodeIfPresent(String.self, forKey: .command)
            )
            actions = try RowActions(from: decoder)
        }

        /// The cell in a column, or an empty one when the row is short.
        public func cell(_ column: Int) -> Cell {
            cells.indices.contains(column) ? cells[column] : Cell("")
        }
    }

    public var columns: [Column]
    public var rows: [Row]
    public var extras: PanelExtras

    public init(columns: [Column], rows: [Row], extras: PanelExtras = PanelExtras()) {
        self.columns = columns
        self.rows = rows
        self.extras = extras
    }

    private enum CodingKeys: String, CodingKey { case columns, rows }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        columns = try container.decodeOneOrMany(Column.self, forKey: .columns)
        rows = try container.decodeIfPresent([Row].self, forKey: .rows) ?? []
        extras = try PanelExtras(from: decoder)
    }
}

/// Which columns a table shows, and how wide, when the tile is too narrow for all of them.
public enum TableLayout {
    /// The `count` columns to show, in their original order: the highest priority first, and
    /// among equals the leftmost, so columns drop from the right.
    public static func visibleColumns(priorities: [Int], fitting count: Int) -> [Int] {
        let kept = priorities.indices
            .sorted { priorities[$0] != priorities[$1] ? priorities[$0] > priorities[$1] : $0 < $1 }
            .prefix(max(count, 0))
        return kept.sorted()
    }

    /// How many columns fit in `available`, given each column's narrowest readable width and the
    /// gap between columns. At most `limit`; at least one when there are any.
    public static func fittingCount(widths: [Double], priorities: [Int], available: Double, spacing: Double, limit: Int = .max) -> Int {
        let priorities = Array(priorities.prefix(widths.count))
        let most = min(priorities.count, max(limit, 0))
        guard most > 0 else { return 0 }
        for count in stride(from: most, through: 1, by: -1) {
            let shown = visibleColumns(priorities: priorities, fitting: count)
            let needed = shown.reduce(0) { $0 + widths[$1] } + spacing * Double(count - 1)
            if needed <= available { return count }
        }
        return 1
    }

    /// Each shown column's width out of `available`. Columns with a share get it; the rest split
    /// what's left: each gets the width it `needs`, and what's over is split evenly. When what's
    /// left is less than they need, they shrink in proportion. Without `needed`, they split it
    /// evenly. Shares that leave the others less than `minimum` each are scaled down, and shares
    /// alone that don't add up to the whole are scaled up.
    public static func widths(shares: [Double?], available: Double, needed: [Double] = [], minimum: Double = 0.1) -> [Double] {
        guard !shares.isEmpty, available > 0 else { return shares.map { _ in 0 } }
        let free = shares.filter { $0 == nil }.count
        var total = shares.reduce(0) { $0 + ($1 ?? 0) }
        let room = free == 0 ? 1 : max(1 - minimum * Double(free), 0)
        let scale = total > 0 && (free == 0 || total > room) ? room / total : 1
        total *= scale
        let left = free == 0 ? 0 : max(1 - total, 0) * available
        let need = shares.indices.map { shares[$0] == nil && $0 < needed.count ? max(needed[$0], 0) : 0 }
        let needs = need.reduce(0, +)
        return shares.indices.map { index in
            if let share = shares[index] { return share * scale * available }
            if needs <= 0 { return left / Double(free) }
            if needs >= left { return need[index] / needs * left }
            return need[index] + (left - needs) / Double(free)
        }
    }
}
