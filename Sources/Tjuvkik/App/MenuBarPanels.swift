import AppKit
import TjuvkikCore

/// What the `menuBar` panels show in the menu bar and its menu.
@MainActor
struct MenuBarPanels {
    struct Entry {
        var title: String
        var menuBar: RowsContent.MenuBar
    }

    let entries: [Entry]

    init(config: Config, panels: PanelStore) {
        entries = config.menuBar.compactMap { name in
            guard let tile = config.tiles.first(where: { $0.panel == name }),
                  case .rows(let rows)? = panels.states[name]?.content,
                  let menuBar = rows.menuBar
            else { return nil }
            return Entry(title: tile.title, menuBar: menuBar)
        }
    }

    /// "❓ 2  ⇡ 3", each part in its tone.
    var title: NSAttributedString {
        let title = NSMutableAttributedString()
        for entry in entries where !entry.menuBar.title.isEmpty {
            if title.length > 0 { title.append(NSAttributedString(string: "  ")) }
            var attributes: [NSAttributedString.Key: Any] = [.font: NSFont.menuBarFont(ofSize: 0)]
            if let color = entry.menuBar.tone?.menuBarColor { attributes[.foregroundColor] = color }
            title.append(NSAttributedString(string: entry.menuBar.title, attributes: attributes))
        }
        return title
    }

    /// A section per panel with rows in its `menu`.
    func addItems(to menu: NSMenu, target: AnyObject, open: Selector) {
        let sections = entries.filter { !($0.menuBar.menu ?? []).isEmpty }
        for entry in sections {
            menu.addItem(.sectionHeader(title: entry.title))
            for row in entry.menuBar.menu ?? [] {
                menu.addItem(Self.item(for: row, target: target, open: open))
            }
        }
        if !sections.isEmpty { menu.addItem(.separator()) }
    }

    private static func item(for row: RowsContent.Row, target: AnyObject, open: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let title = NSMutableAttributedString(
            string: [row.icon, row.title].compactMap { $0 }.joined(separator: "  "),
            attributes: [.font: NSFont.menuFont(ofSize: 0), .foregroundColor: row.tone?.menuBarColor ?? NSColor.labelColor]
        )
        if let trailing = row.trailing {
            title.append(NSAttributedString(string: "   \(trailing)", attributes: [
                .font: NSFont.menuFont(ofSize: 0), .foregroundColor: NSColor.secondaryLabelColor,
            ]))
        }
        item.attributedTitle = title
        item.subtitle = [row.subtitle, row.note].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
        // Rows without a link still read clearly: enabled, but with nothing to do.
        if let link = row.url.flatMap(URL.init(string:)) {
            item.action = open
            item.target = target
            item.representedObject = link
        } else {
            item.action = #selector(NSMenuItem.ignore)
            item.target = item
        }
        return item
    }
}

private extension NSMenuItem {
    @objc func ignore() {}
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension Tone {
    /// System colors, since the menu bar follows the system, not the glance theme.
    var menuBarColor: NSColor? {
        switch self {
        case .normal: nil
        case .muted: .secondaryLabelColor
        case .warning: .systemOrange
        case .error: .systemRed
        case .success: .systemGreen
        case .info: .systemTeal
        case .accent: .systemPurple
        }
    }
}

extension NSAttributedString {
    func appending(_ other: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: self)
        result.append(other)
        return result
    }
}
