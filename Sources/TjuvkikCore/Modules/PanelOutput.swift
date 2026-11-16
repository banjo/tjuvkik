import Foundation

/// What a panel's output becomes on its tile. Shared by the app and `tjuvkik run`.
public enum PanelOutput {
    /// A script's JSON as its content type, or a cli panel's text as is, colors removed.
    public static func content(_ output: Data, for tile: Tile) -> Result<ModuleContent, ScriptOutputError> {
        switch tile.kind {
        case .script: ScriptOutput.content(output, as: tile.content)
        case .cli: .success(.text(TerminalText.clean(String(decoding: output, as: UTF8.self))))
        }
    }
}

extension ModuleContent {
    /// What the tile shows, in a few words: "table, 4 columns and 8 rows".
    public var outline: String {
        switch self {
        case .rows(let content):
            var parts = [count(content.rows.count, "row")]
            if let hero = content.hero { parts.insert("hero \(hero.value)", at: 0) }
            if let summary = content.summary, !summary.isEmpty { parts.append(count(summary.count, "summary chip")) }
            if let progress = content.progress { parts.append("progress \(Int((progress * 100).rounded()))%") }
            return "rows, " + list(parts)
        case .text(let text), .tail(let text):
            return "text, " + count(text.split(separator: "\n", omittingEmptySubsequences: false).count, "line")
        case .chart(let content):
            let value = content.value + (content.unit ?? "")
            return "chart, \(value)" + (content.series.isEmpty ? "" : ", " + count(content.series.count, "value"))
        case .meters(let content):
            return "meters, " + count(content.meters.count, "meter")
        case .grid(let content):
            if let levels = content.levels { return "grid, a heatmap of " + count(levels.count, "row") }
            return "grid, " + count(content.rows.count, "row")
        case .timeline(let content):
            return "timeline, " + count(content.events.count, "event")
        case .stats(let content):
            return "stats, " + count(content.stats.count, "stat")
        case .markdown(let content):
            return "markdown, " + count(content.blocks.count, "block")
        case .keyvalue(let content):
            let titled = content.sections.filter { $0.title != nil }.count
            let pairs = count(content.pairs.count, "pair")
            return "key-value, " + (titled > 0 ? "\(pairs) in \(count(titled, "section"))" : pairs)
        case .table(let content):
            return "table, " + list([count(content.columns.count, "column"), count(content.rows.count, "row")])
        case .feed(let content):
            let unread = content.items.filter(\.unread).count
            return "feed, " + count(content.items.count, "item") + (unread > 0 ? ", \(unread) unread" : "")
        case .checklist(let content):
            return "checklist, \(content.done) of \(content.total) done"
        }
    }

    private func count(_ number: Int, _ noun: String) -> String {
        "\(number) \(noun)\(number == 1 ? "" : "s")"
    }

    private func list(_ parts: [String]) -> String {
        switch parts.count {
        case 0: ""
        case 1: parts[0]
        default: parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
        }
    }
}
