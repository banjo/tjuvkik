import AppKit
import SwiftUI
import TjuvkikCore

/// Spotlight: the search field, a tab per panel, the list, and the picked row's panel drawn as
/// on the board, at the size of a 2x2 tile.
struct SpotlightView: View {
    let model: SpotlightModel
    let store: ConfigStore
    let panels: PanelStore
    let field: SearchFieldReference
    /// A click on a row in the list, by its index.
    let onPick: (Int) -> Void
    let onTab: (Int) -> Void
    let onAction: (Tile, RowAction) -> Void
    let menu: (Tile) -> TileMenu

    // At zoom 1.
    static let listWidth: CGFloat = 320
    static let searchHeight: CGFloat = 50
    static let tabsHeight: CGFloat = 40
    static let footHeight: CGFloat = 34
    static let previewPadding: CGFloat = 12
    /// Room around the frame for its shadow.
    static let shadowSpace: CGFloat = 24
    static let previewSize = TileSize.l

    /// The window at zoom 1.
    static func size(search: Bool, theme: Theme) -> CGSize {
        let preview = BentoGeometry.size(of: previewSize, board: theme.board)
        return CGSize(
            width: listWidth + 1 + preview.width + previewPadding * 2 + shadowSpace * 2,
            height: (search ? searchHeight : 0) + tabsHeight + preview.height + previewPadding * 2 + footHeight + shadowSpace * 2
        )
    }

    var body: some View {
        let config = store.config
        let theme = config.theme(dark: model.systemIsDark).zoomed(model.zoom)
        let list = SpotlightList(config: config, states: panels.states, tab: model.tab, query: model.query)
        let selected = list.index(of: model.selectedID, fallback: model.selected)
        let picked = selected.map { list.items[$0] }
        let radius = theme.z(18)
        VStack(spacing: 0) {
            if model.search {
                SearchRow(model: model, field: field, placeholder: placeholder(list), theme: theme)
                Divider().overlay(Color(theme.line))
            }
            TabsRow(tabs: list.tabs, selected: model.tab, onTab: onTab, theme: theme)
            Divider().overlay(Color(theme.line))
            HStack(spacing: 0) {
                SpotlightListView(list: list, allTab: model.tab == 0, selected: selected, query: model.query, onPick: onPick, theme: theme)
                    .frame(width: theme.z(Self.listWidth))
                Rectangle().fill(Color(theme.line)).frame(width: 1)
                preview(picked, config: config, theme: theme)
                    .padding(theme.z(Self.previewPadding))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider().overlay(Color(theme.line))
            SpotlightFoot(item: picked, sticky: model.sticky, theme: theme)
                .frame(height: theme.z(Self.footHeight))
        }
        .overlay(alignment: .bottomTrailing) {
            if let actions = model.menu {
                ActionMenuView(menu: actions, theme: theme)
                    .padding(.trailing, theme.z(Self.previewPadding))
                    .padding(.bottom, theme.z(Self.footHeight + 6))
            }
        }
        .background {
            if theme.blur {
                ZStack {
                    VisualEffect(cornerRadius: radius, appearance: theme.appearance, material: theme.material)
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color(theme.panel))
                }
            } else {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color(theme.panel.opaque))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color(theme.line), lineWidth: 1))
        .shadow(color: .black.opacity(theme.blur ? 0.25 : 0.4), radius: theme.z(20), y: theme.z(10))
        .padding(theme.z(Self.shadowSpace))
        .opacity(model.isVisible ? 1 : 0)
        .scaleEffect(model.isVisible ? 1 : 0.98, anchor: .top)
        .animation(.easeOut(duration: 0.18), value: model.isVisible)
        .environment(\.colorScheme, theme.appearance.colorScheme)
    }

    private func placeholder(_ list: SpotlightList) -> String {
        let tab = list.tabs.indices.contains(model.tab) ? list.tabs[model.tab] : nil
        return tab?.tile == nil ? "Search all panels" : "Search \(tab?.title ?? "")"
    }

    /// Drawn at the preview's size, so its type lays out for it.
    private static func previewTile(_ tile: Tile) -> Tile {
        var tile = tile
        tile.size = previewSize
        return tile
    }

    /// A row's details, or the whole panel for one that stands for its panel.
    @ViewBuilder private func preview(_ item: SpotlightItem?, config: Config, theme: Theme) -> some View {
        if let item, item.kind == .row, let tile = config.tiles.first(where: { $0.id == item.tile }) {
            SpotlightDetail(item: item, tile: tile, state: panels.states[tile.id], theme: theme)
        } else if let tile = item.flatMap({ item in config.tiles.first { $0.id == item.tile } }).map(Self.previewTile) {
            let size = BentoGeometry.size(of: Self.previewSize, board: theme.board)
            TileView(tile: tile, state: panels.states[tile.id], theme: theme, index: 0, isVisible: model.isVisible,
                     onAction: { onAction(tile, $0) }, menu: menu(tile))
                .frame(width: theme.z(size.width), height: theme.z(size.height))
                .id(tile.id)
        } else {
            Color.clear
        }
    }
}

/// Holds the search field, so the controller can give it the keyboard.
@MainActor
final class SearchFieldReference {
    weak var view: NSTextField?
}

private struct SearchRow: View {
    let model: SpotlightModel
    let field: SearchFieldReference
    let placeholder: String
    let theme: Theme

    var body: some View {
        HStack(spacing: theme.z(10)) {
            Image(systemName: "magnifyingglass")
                .font(theme.font(16, weight: .medium))
                .foregroundStyle(Color(theme.secondaryText))
            SearchField(text: Binding(get: { model.query }, set: { query in
                model.query = query
                model.selected = 0
                model.selectedID = nil
            }), placeholder: placeholder, reference: field, theme: theme)
        }
        .padding(.horizontal, theme.z(16))
        .frame(height: theme.z(SpotlightView.searchHeight))
    }
}

/// An AppKit text field: SwiftUI's can't be given the keyboard in a window that's never active.
private struct SearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let reference: SearchFieldReference
    let theme: Theme

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        reference.view = field
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.text = $text
        if field.stringValue != text { field.stringValue = text }
        let font = theme.nsFont(17)
        field.font = font
        field.textColor = NSColor(Color(theme.text))
        field.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: [
            .font: font, .foregroundColor: NSColor(Color(theme.tertiaryText)),
        ])
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

private struct TabsRow: View {
    let tabs: [SpotlightList.Tab]
    let selected: Int
    let onTab: (Int) -> Void
    let theme: Theme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: theme.z(2)) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        HStack(spacing: theme.z(6)) {
                            Text(tab.title)
                                .font(theme.font(12.5, weight: .medium))
                                .foregroundStyle(Color(index == selected ? theme.text : theme.secondaryText))
                                .lineLimit(1)
                            if let count = tab.count {
                                Text("\(count)")
                                    .font(theme.font(10.5, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(Color(count == 0 ? theme.tertiaryText : theme.accent))
                                    .padding(.horizontal, theme.z(6))
                                    .padding(.vertical, theme.z(1))
                                    .background(Color(theme.well), in: Capsule())
                            }
                        }
                        .padding(.horizontal, theme.z(10))
                        .frame(height: theme.z(28))
                        .background(index == selected ? Color(theme.well) : .clear,
                                    in: RoundedRectangle(cornerRadius: theme.z(8), style: .continuous))
                        .contentShape(Rectangle())
                        .onTapGesture { onTab(index) }
                        .id(index)
                    }
                }
                .padding(.horizontal, theme.z(10))
            }
            .scrollIndicators(.never)
            .onChange(of: selected) { _, tab in
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(tab) }
            }
        }
        .frame(height: theme.z(SpotlightView.tabsHeight))
    }
}

private struct SpotlightListView: View {
    let list: SpotlightList
    /// Every panel is listed: each gets a heading.
    let allTab: Bool
    let selected: Int?
    let query: String
    let onPick: (Int) -> Void
    let theme: Theme

    var body: some View {
        if list.items.isEmpty {
            Text(query.isEmpty ? "No panels on the board" : "No matches for “\(query)”")
                .font(theme.font(12.5))
                .foregroundStyle(Color(theme.tertiaryText))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: theme.z(1)) {
                        ForEach(entries, id: \.id) { entry in
                            switch entry {
                            case .heading(_, let title, let count):
                                Heading(title: title, count: count, theme: theme)
                            case .item(let index, let item):
                                SpotlightRow(item: item, selected: index == selected, theme: theme)
                                    .contentShape(Rectangle())
                                    .onTapGesture { onPick(index) }
                            }
                        }
                    }
                    .padding(theme.z(6))
                }
                .onChange(of: selected) { _, index in
                    guard let index else { return }
                    proxy.scrollTo(Entry.itemID(index))
                }
            }
        }
    }

    private enum Entry {
        /// Its id, its title and how many items it heads.
        case heading(String, String, count: Int?)
        case item(Int, SpotlightItem)

        static func itemID(_ index: Int) -> String { "item \(index)" }

        var id: String {
            switch self {
            case .heading(let id, _, _): id
            case .item(let index, _): Self.itemID(index)
            }
        }
    }

    /// The items, under a heading per panel in the All tab, or per group in a panel's own.
    private var entries: [Entry] {
        var entries: [Entry] = []
        var index = 0
        for section in list.sections {
            if allTab { entries.append(.heading("panel \(section.tile)", section.title, count: section.count)) }
            var group: String?
            for item in section.items {
                if !allTab, let name = item.group, name != group { entries.append(.heading("group \(index) \(name)", name, count: nil)) }
                group = item.group
                entries.append(.item(index, item))
                index += 1
            }
        }
        return entries
    }

    private struct Heading: View {
        let title: String
        let count: Int?
        let theme: Theme

        var body: some View {
            HStack(spacing: theme.z(6)) {
                Text(title)
                    .font(theme.font(10.5, weight: .semibold))
                    .foregroundStyle(Color(theme.tertiaryText))
                    .textCase(.uppercase)
                    .lineLimit(1)
                if let count {
                    Text("\(count)").font(theme.font(10.5).monospacedDigit()).foregroundStyle(Color(theme.tertiaryText))
                }
            }
            .padding(.horizontal, theme.z(8))
            .padding(.top, theme.z(10))
            .padding(.bottom, theme.z(3))
        }
    }
}

private struct SpotlightRow: View {
    let item: SpotlightItem
    let selected: Bool
    let theme: Theme
    @State private var hovering = false

    var body: some View {
        HStack(spacing: theme.z(8)) {
            Group {
                switch item.kind {
                case .panel:
                    Image(systemName: "square.grid.2x2").font(theme.font(12, weight: .medium)).foregroundStyle(Color(theme.secondaryText))
                case .more:
                    Image(systemName: "ellipsis").font(theme.font(12, weight: .medium)).foregroundStyle(Color(theme.tertiaryText))
                case .row:
                    if let icon = Icon(item.icon) {
                    IconView(icon: icon, size: 13, color: theme.color(for: item.tone, default: theme.secondaryText), theme: theme)
                    } else if let tone = item.tone, tone != .normal {
                        Circle().fill(theme.color(for: tone, default: theme.secondaryText)).frame(width: theme.z(6), height: theme.z(6))
                    }
                }
            }
            .frame(width: theme.z(18))
            VStack(alignment: .leading, spacing: theme.z(1)) {
                Text(item.title)
                    .font(theme.font(12.5, weight: item.kind == .row ? .medium : .regular))
                    .foregroundStyle(Color(item.tone == .muted || item.kind != .row ? theme.secondaryText : theme.text))
                    .lineLimit(1)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(theme.font(11)).foregroundStyle(Color(theme.tertiaryText)).lineLimit(1)
                }
            }
            Spacer(minLength: theme.z(4))
            if let trailing = item.trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(theme.font(11).monospacedDigit())
                    .foregroundStyle(theme.color(for: item.tone, default: theme.tertiaryText))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, theme.z(8))
        .padding(.vertical, theme.z(5))
        .frame(minHeight: theme.z(32))
        .background(selected ? Color(theme.accent).opacity(0.22) : hovering ? Color(theme.well) : .clear,
                    in: RoundedRectangle(cornerRadius: theme.z(7), style: .continuous))
        .onHover { hovering = $0 }
    }
}

/// What the keys do with the picked row, and how to move between tabs and close.
private struct SpotlightFoot: View {
    let item: SpotlightItem?
    /// The keys work: Spotlight stays open.
    let sticky: Bool
    let theme: Theme

    var body: some View {
        let row = item.flatMap(SpotlightController.action)
        HStack(spacing: theme.z(14)) {
            if sticky {
                if case .more? = item?.kind {
                    hintView("↵", "Show All")
                } else {
                    ForEach(Array(GlanceCommand.hints(for: row).enumerated()), id: \.offset) { _, hint in
                        hintView(hint.keys, hint.title)
                    }
                }
                hintView("↑↓", "Select")
                hintView("⇥", "Panels")
                hintView("esc", "Close")
            } else {
                Text("Click or press Space to keep it open").font(theme.font(11.5)).foregroundStyle(Color(theme.secondaryText))
            }
            Spacer()
        }
        .padding(.horizontal, theme.z(14))
    }

    private func hintView(_ keys: String, _ title: String) -> some View {
        HStack(spacing: theme.z(5)) {
            KeyCap(keys: keys, theme: theme)
            Text(title).font(theme.font(11.5)).foregroundStyle(Color(theme.secondaryText)).lineLimit(1)
        }
    }
}
