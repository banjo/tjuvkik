import AppKit
import TjuvkikCore

/// What the `menuBar` panels show in the menu bar and its menu.
@MainActor
struct MenuBarPanels {
    struct Entry {
        var id: String
        var title: String
        var menuBar: RowsContent.MenuBar
    }

    /// What picking a menu row does.
    enum Action {
        case open(URL)
        case run(command: String, id: String)
    }

    let entries: [Entry]

    init(config: Config, panels: PanelStore) {
        entries = config.menuBar.compactMap { name in
            guard let tile = config.tiles.first(where: { $0.id == name }),
                  let menuBar = panels.states[name]?.content?.menuBar
            else { return nil }
            return Entry(id: name, title: tile.title, menuBar: menuBar)
        }
    }

    /// "❓ 2  ⇡ 3", each part in its tone.
    var title: NSAttributedString {
        let title = NSMutableAttributedString()
        for entry in entries where !entry.menuBar.title.isEmpty {
            if title.length > 0 { title.append(NSAttributedString(string: "  ")) }
            let font = NSFont.menuBarFont(ofSize: 0)
            let color = entry.menuBar.tone?.menuBarColor
            var attributes: [NSAttributedString.Key: Any] = [.font: font]
            if let color { attributes[.foregroundColor] = color }
            let icon = Icon(entry.menuBar.icon)
            if let icon {
                title.append(Self.string(for: icon, font: font, color: color, attributes: attributes))
            }
            if let text = entry.menuBar.text, !text.isEmpty {
                title.append(NSAttributedString(string: icon == nil ? text : " \(text)", attributes: attributes))
            }
        }
        return title
    }

    /// An icon inline in the menu bar's text. The menu bar doesn't animate, so a spinner is a still
    /// symbol and a symbol's effect is left out.
    private static func string(for icon: Icon, font: NSFont, color: NSColor?, attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let name: String
        switch icon {
        case .text(let text): return NSAttributedString(string: text, attributes: attributes)
        case .symbol(let symbol, _): name = symbol
        case .spinner: name = "progress.indicator"
        }
        guard let image = symbolImage(name, pointSize: font.pointSize, color: color ?? .labelColor) else {
            return NSAttributedString()
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: (font.capHeight - image.size.height) / 2, width: image.size.width, height: image.size.height)
        return NSAttributedString(attachment: attachment)
    }

    /// A symbol in `color`, or a template that follows the menu's text color without one.
    private static func symbolImage(_ name: String, pointSize: CGFloat, color: NSColor?) -> NSImage? {
        var configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        if let color { configuration = configuration.applying(.init(paletteColors: [color])) }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
        image?.isTemplate = color == nil
        return image
    }

    /// A section per panel with rows in its `menu`.
    /// `perform` gets the item; its `representedObject` is an `Action`.
    func addItems(to menu: NSMenu, target: AnyObject, perform: Selector) {
        let sections = entries.filter { !($0.menuBar.menu ?? []).isEmpty }
        for entry in sections {
            menu.addItem(.sectionHeader(title: entry.title))
            for row in entry.menuBar.menu ?? [] {
                menu.addItem(Self.item(for: row, id: entry.id, target: target, perform: perform))
            }
        }
        if !sections.isEmpty { menu.addItem(.separator()) }
    }

    private static func item(for row: RowsContent.Row, id: String, target: AnyObject, perform: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let icon = Icon(row.icon)
        let title = NSMutableAttributedString(
            string: [icon?.text, row.title].compactMap { $0 }.joined(separator: "  "),
            attributes: [.font: NSFont.menuFont(ofSize: 0), .foregroundColor: row.tone?.menuBarColor ?? NSColor.labelColor]
        )
        switch icon {
        case .symbol(let name, _): item.image = symbolImage(name, pointSize: NSFont.menuFont(ofSize: 0).pointSize, color: row.tone?.menuBarColor)
        case .spinner: item.image = symbolImage("progress.indicator", pointSize: NSFont.menuFont(ofSize: 0).pointSize, color: row.tone?.menuBarColor)
        case .text, nil: break
        }
        if let trailing = row.trailing {
            title.append(NSAttributedString(string: "   \(trailing)", attributes: [
                .font: NSFont.menuFont(ofSize: 0), .foregroundColor: NSColor.secondaryLabelColor,
            ]))
        }
        item.attributedTitle = title
        item.subtitle = [row.subtitle, row.note].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
        let action: Action? = if let command = row.command, !command.isEmpty {
            .run(command: command, id: id)
        } else {
            row.url.flatMap(URL.init(string:)).map(Action.open)
        }
        // Rows with nothing to do still read clearly: enabled, but inert.
        if let action {
            item.action = perform
            item.target = target
            item.representedObject = action
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
