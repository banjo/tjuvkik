import Foundation

/// What a script prints next to its content, whatever the type: a summary line and what the
/// panel shows in the menu bar.
public struct PanelExtras: Equatable, Sendable, Decodable {
    public var summary: [RowsContent.Chip]?
    public var menuBarSetting: RowsContent.MenuBarSetting

    public init(summary: [RowsContent.Chip]? = nil, menuBar: RowsContent.MenuBarSetting = .automatic) {
        self.summary = summary
        self.menuBarSetting = menuBar
    }

    private enum CodingKeys: String, CodingKey { case summary, menuBar }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decodeIfPresent([RowsContent.Chip].self, forKey: .summary)
        if !container.contains(.menuBar) {
            menuBarSetting = .automatic
        } else if try container.decodeNil(forKey: .menuBar) {
            menuBarSetting = .hidden
        } else {
            menuBarSetting = .custom(try container.decode(RowsContent.MenuBar.self, forKey: .menuBar))
        }
    }

    /// What the menu bar shows for this panel, or nil for nothing.
    public var menuBar: RowsContent.MenuBar? {
        switch menuBarSetting {
        case .hidden: return nil
        case .custom(let menuBar): return menuBar
        case .automatic:
            guard let summary, let first = summary.first else { return nil }
            let line = summary.map { [$0.icon, $0.value, $0.label].compactMap { $0 }.joined(separator: " ") }.joined(separator: "  ·  ")
            return RowsContent.MenuBar(icon: first.icon, text: first.value, tone: first.tone, menu: [RowsContent.Row(title: line)])
        }
    }
}
