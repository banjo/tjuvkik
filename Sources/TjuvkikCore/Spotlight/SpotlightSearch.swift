import Foundation

/// A row in Spotlight's list: a panel's row, item, event, task, pair or line, whatever its type.
public struct SpotlightItem: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case row
        /// It stands for the whole panel, which has nothing to list.
        case panel
        /// The rows of the panel left out of the All tab: this many.
        case more(Int)
    }

    /// A label and a value the preview shows, like a table cell under its column's title.
    public struct Detail: Equatable, Sendable {
        public var label: String
        public var value: String
        public var tone: Tone?

        public init(_ label: String, _ value: String, tone: Tone? = nil) {
            self.label = label
            self.value = value
            self.tone = tone
        }
    }

    /// The tile it's from.
    public var tile: String
    public var icon: String?
    public var title: String
    public var subtitle: String?
    public var trailing: String?
    public var tone: Tone?
    /// The heading it's listed under in its panel's tab.
    public var group: String?
    /// What needs attention, shown in the preview in the row's tone.
    public var note: String?
    public var details: [Detail] = []
    public var url: String?
    public var command: String?
    public var actions = RowActions()
    public var kind = Kind.row
    /// Stays the same while the panel updates around it, so the pick follows the row. Set by
    /// `SpotlightSearch.sections`.
    public var id = ""

    public init(tile: String, icon: String? = nil, title: String, subtitle: String? = nil, trailing: String? = nil, tone: Tone? = nil,
                group: String? = nil, note: String? = nil, details: [Detail] = [], url: String? = nil, command: String? = nil,
                actions: RowActions = RowActions(), kind: Kind = .row) {
        self.tile = tile
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.tone = tone
        self.group = group
        self.note = note
        self.details = details
        self.url = url
        self.command = command
        self.actions = actions
        self.kind = kind
    }
}

/// A panel as Spotlight lists it.
public struct SpotlightPanel: Equatable, Sendable {
    public var tile: String
    public var title: String
    /// "script", "cli" or the content type, for a panel with nothing to list.
    public var typeName: String
    public var content: ModuleContent?
    /// Why there's no content yet: "Loading…", or the error.
    public var status: String?

    public init(tile: String, title: String, typeName: String, content: ModuleContent?, status: String? = nil) {
        self.tile = tile
        self.title = title
        self.typeName = typeName
        self.content = content
        self.status = status
    }
}

/// A panel's items that match the search.
public struct SpotlightSection: Equatable, Sendable {
    public var tile: String
    public var title: String
    public var items: [SpotlightItem]
    /// How many match, including those a limit left out.
    public var count: Int
}

public enum SpotlightSearch {
    /// Lines of a cli panel's output listed, at most.
    public static let lineLimit = 200

    /// Each panel's items that match `query`, in order. A panel with nothing to list is one item
    /// that stands for it. Panels without a match are left out. With `limit`, a panel lists that
    /// many and then one item that says how many more it has.
    public static func sections(_ panels: [SpotlightPanel], query: String, limit: Int? = nil,
                                now: Date = Date(), calendar: Calendar = .current) -> [SpotlightSection] {
        let tokens = self.tokens(query)
        return panels.compactMap { panel in
            var items = identified(items(panel.content, tile: panel.tile, now: now, calendar: calendar))
            if items.isEmpty {
                let subtitle = panel.status ?? (panel.content.map(lists) == true ? "Nothing to show" : panel.typeName)
                var item = SpotlightItem(tile: panel.tile, title: panel.title, subtitle: subtitle, kind: .panel)
                item.id = "\(panel.tile)\u{1F}panel"
                items = [item]
            }
            var matching = tokens.isEmpty ? items : items.filter { matches($0, panelTitle: panel.title, tokens: tokens) }
            let count = matching.count
            if let limit, matching.count > limit + 1 {
                var more = SpotlightItem(tile: panel.tile, title: "\(matching.count - limit) more in \(panel.title)", kind: .more(matching.count - limit))
                more.id = "\(panel.tile)\u{1F}more"
                matching = Array(matching.prefix(limit)) + [more]
            }
            return matching.isEmpty ? nil : SpotlightSection(tile: panel.tile, title: panel.title, items: matching, count: count)
        }
    }

    /// An id from what the row does, or its title, and how many before it in the panel have the
    /// same.
    private static func identified(_ items: [SpotlightItem]) -> [SpotlightItem] {
        var seen: [String: Int] = [:]
        return items.map { item in
            var item = item
            let target = [item.url, item.command].compactMap { $0 }.first { !$0.isEmpty } ?? item.title
            let key = "\(item.tile)\u{1F}\(target)"
            let ordinal = seen[key, default: 0]
            seen[key] = ordinal + 1
            item.id = "\(key)\u{1F}\(ordinal)"
            return item
        }
    }

    /// Every word of the query is somewhere in the item's texts or its panel's title, ignoring
    /// case and accents.
    static func matches(_ item: SpotlightItem, panelTitle: String, tokens: [String]) -> Bool {
        let texts = [item.title, item.subtitle, item.trailing, item.group, item.note, panelTitle].compactMap { $0 } + item.details.map(\.value)
        let text = fold(texts.joined(separator: " "))
        return tokens.allSatisfy(text.contains)
    }

    static func tokens(_ query: String) -> [String] {
        fold(query).split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// Whether the content is a list of things, even when it's empty. Charts and markdown aren't.
    private static func lists(_ content: ModuleContent) -> Bool {
        switch content {
        case .chart, .markdown: false
        default: true
        }
    }

    /// What a panel's content lists. Charts and markdown have nothing to list.
    public static func items(_ content: ModuleContent?, tile: String, now: Date = Date(), calendar: Calendar = .current) -> [SpotlightItem] {
        switch content {
        case nil, .chart, .markdown:
            return []
        case .rows(let rows):
            return rows.rows.map {
                SpotlightItem(tile: tile, icon: $0.icon, title: $0.title, subtitle: $0.subtitle, trailing: $0.trailing, tone: $0.tone,
                              group: $0.group, note: $0.note, url: $0.url, command: $0.command, actions: $0.actions)
            }
        case .text(let text):
            return lines(text, tile: tile)
        case .tail(let text):
            return lines(text, tile: tile, tail: true)
        case .table(let table):
            return table.rows.map { row in
                let rest = row.cells.dropFirst().map(\.text).filter { !$0.isEmpty }
                let details = table.columns.indices.dropFirst().compactMap { index -> SpotlightItem.Detail? in
                    let cell = row.cell(index)
                    return cell.text.isEmpty ? nil : .init(table.columns[index].title, cell.text, tone: cell.tone)
                }
                return SpotlightItem(tile: tile, title: row.cell(0).text, subtitle: rest.isEmpty ? nil : rest.joined(separator: " · "),
                                     tone: row.highlight, details: details, url: row.url, command: row.command, actions: row.actions)
            }
        case .timeline(let timeline):
            return timeline.snapshot(now: now, calendar: calendar).items.map { item in
                SpotlightItem(tile: tile, title: item.event.title, subtitle: item.event.subtitle, trailing: item.time, tone: item.event.tone,
                              details: [.init("When", item.time)], url: item.event.url, command: item.event.command, actions: item.event.actions)
            }
        case .feed(let feed):
            return feed.newestFirst.map { item in
                let from = [item.author, item.place].compactMap { $0 }.filter { !$0.isEmpty }
                let when = item.when(now: now, calendar: calendar)
                let details = [item.author.map { SpotlightItem.Detail("From", $0) }, item.place.map { .init("Where", $0) }, when.map { .init("When", $0) }]
                return SpotlightItem(tile: tile, icon: item.icon, title: item.text.replacing("**", with: ""),
                                     subtitle: from.isEmpty ? nil : from.joined(separator: " · "), trailing: when,
                                     tone: item.unread ? .accent : nil, details: details.compactMap { $0 }, url: item.url, actions: item.actions)
            }
        case .checklist(let checklist):
            var section: String?
            return checklist.items.compactMap { item in
                switch item {
                case .section(let title):
                    section = title
                    return nil
                case .task(let task):
                    let details = [SpotlightItem.Detail("Status", task.state.rawValue), task.who.map { .init("Who", $0) }]
                    return SpotlightItem(tile: tile, title: task.title, subtitle: task.who, trailing: task.state.rawValue, group: section,
                                         note: task.note, details: details.compactMap { $0 })
                }
            }
        case .keyvalue(let keyvalue):
            return keyvalue.sections.flatMap { section in
                section.pairs.map { SpotlightItem(tile: tile, title: $0.key, trailing: $0.value, tone: $0.tone, group: section.title) }
            }
        case .grid(let grid):
            return grid.rows.map { SpotlightItem(tile: tile, title: $0.label, trailing: $0.value, tone: $0.status) }
        case .meters(let meters):
            return meters.meters.map { meter in
                let value = [meter.text, meter.of.map { "of \($0)" }].compactMap { $0 }.joined(separator: " ")
                return SpotlightItem(tile: tile, title: meter.label ?? meter.text, trailing: meter.label == nil ? nil : value, tone: meter.tone)
            }
        case .stats(let stats):
            return stats.stats.map { stat in
                let value = [stat.value, stat.unit].compactMap { $0 }.joined(separator: " ")
                let details = [stat.delta.map { SpotlightItem.Detail("Change", $0, tone: stat.tone) }, stat.vs.map { .init("Compared to", $0) }]
                return SpotlightItem(tile: tile, title: stat.label ?? value, subtitle: stat.delta, trailing: stat.label == nil ? nil : value,
                                     tone: stat.tone, details: details.compactMap { $0 })
            }
        }
    }

    /// Its lines, without blank ones. A tail's newest first.
    private static func lines(_ text: String, tile: String, tail: Bool = false) -> [SpotlightItem] {
        let lines = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let listed = tail ? Array(lines.suffix(lineLimit).reversed()) : Array(lines.prefix(lineLimit))
        return listed.map { SpotlightItem(tile: tile, title: $0) }
    }
}
