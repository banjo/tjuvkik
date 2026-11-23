import AppKit
import Carbon.HIToolbox
import SwiftUI
import TjuvkikCore

@MainActor
@Observable
final class SpotlightModel {
    var isVisible = false
    var systemIsDark = false
    var zoom: CGFloat = 1
    /// Spotlight has a search field, from `"search"`.
    var search = true
    /// It stays open: toggled, or pinned.
    var sticky = false
    var query = ""
    /// 0 lists every panel; then one tab per panel on the board, in `panels` order.
    var tab = 0
    /// The picked row, which the pick follows while its panel updates.
    var selectedID: String?
    /// Where the picked row was in the tab's list, across its sections: the pick when the row
    /// is gone.
    var selected = 0
    /// The ⌘K list, while it's open.
    var menu: ActionMenu?
}

/// The tabs and what the open one lists, for the search as it is.
struct SpotlightList {
    struct Tab: Equatable {
        /// Nil for the tab that lists every panel.
        var tile: String?
        var title: String
        /// What matches the search in it; nil while there's no search.
        var count: Int?
    }

    /// Rows per panel in the All tab while there's no search.
    static let allLimit = 5

    var tabs: [Tab]
    var sections: [SpotlightSection]
    var items: [SpotlightItem]

    init(config: Config, states: [String: PanelStore.State], tab: Int, query: String) {
        let panels = config.tiles.filter { $0.slot != nil }.map { tile in
            let state = states[tile.id]
            let content = state?.content
            return SpotlightPanel(tile: tile.id, title: tile.title, typeName: content?.type?.rawValue ?? tile.typeName, content: content,
                                  status: content == nil ? state?.error ?? "Loading…" : nil)
        }
        let searching = !query.trimmingCharacters(in: .whitespaces).isEmpty
        let all = SpotlightSearch.sections(panels, query: query, limit: searching || tab != 0 ? nil : Self.allLimit)
        let count = { (tile: String?) -> Int? in
            guard searching else { return nil }
            return all.filter { tile == nil || $0.tile == tile }.reduce(0) { $0 + $1.count }
        }
        tabs = [Tab(tile: nil, title: "All", count: count(nil))] + panels.map { Tab(tile: $0.tile, title: $0.title, count: count($0.tile)) }
        let tile = tabs.indices.contains(tab) ? tabs[tab].tile : nil
        sections = tile.map { tile in all.filter { $0.tile == tile } } ?? all
        items = sections.flatMap(\.items)
    }

    /// Where the row with `id` is, or else the one at `fallback`, kept in the list.
    func index(of id: String?, fallback: Int) -> Int? {
        guard !items.isEmpty else { return nil }
        if let id, let index = items.firstIndex(where: { $0.id == id }) { return index }
        return min(max(fallback, 0), items.count - 1)
    }

    func tab(of tile: String) -> Int? {
        tabs.firstIndex { $0.tile == tile }
    }
}

/// Spotlight: every panel's rows in one list, a tab per panel, and the picked row's panel beside
/// it. With `"search"` it has a search field, and while it stays open it takes the keyboard from
/// the app in front, without activating Tjuvkik, so you can type.
@MainActor
final class SpotlightController: GlanceSurface {
    private var window: GlanceWindow!
    private let model = SpotlightModel()
    private let store: ConfigStore
    private let panels: PanelStore
    private let field = SearchFieldReference()
    private var keyMonitor: Any?

    var onShow: () -> Void = {}
    var onHide: () -> Void = {}
    var onMouseDown: () -> Void = {}
    var onDismiss: () -> Void = {} {
        didSet { window.onDismiss = onDismiss }
    }
    var onRowAction: (Tile, RowAction) -> Void = { _, _ in }
    var onCommand: (Tile, RowAction?, GlanceCommand.Kind) -> Void = { _, _, _ in }
    var onRowKeys: ([String]) -> Void = { _ in }
    var tileMenu: (Tile) -> TileMenu = { _ in TileMenu() }
    var closesOnClickOutside: Bool {
        get { window.closesOnClickOutside }
        set { window.closesOnClickOutside = newValue }
    }

    init(store: ConfigStore, panels: PanelStore) {
        self.store = store
        self.panels = panels
        let hosting = GlanceHostingView(rootView: SpotlightView(
            model: model, store: store, panels: panels, field: field,
            onPick: { [weak self] index in self?.pick(index) },
            onTab: { [weak self] tab in self?.select(tab: tab) },
            onAction: { [weak self] tile, action in self?.onRowAction(tile, action) },
            menu: { [weak self] tile in self?.tileMenu(tile) ?? TileMenu() }
        ))
        window = GlanceWindow(content: hosting)
        window.panel.onMouseDown = { [weak self] in self?.onMouseDown() }
        window.onAppearanceChange = { [model] dark in model.systemIsDark = dark }
        model.systemIsDark = window.systemIsDark
    }

    func show(sticky: Bool) {
        guard let screen = FocusedScreen.current() else { return }
        let config = store.config
        model.search = config.search
        model.query = ""
        model.tab = 0
        model.selected = 0
        model.selectedID = nil
        model.menu = nil
        let size = SpotlightView.size(search: config.search, theme: config.theme(dark: model.systemIsDark))
        let framed = GlancePlacement.framed(in: screen.visibleFrame, content: size, zoom: config.zoom)
        model.zoom = framed.zoom
        window.show(framed.rect, on: screen, dim: config.dim)
        model.isVisible = true
        rowKeysChanged()
        if sticky { stick() }
        onShow()
    }

    func stick() {
        guard window.stick() else { return }
        model.sticky = true
        guard store.config.search else { return }
        window.takeKeyboard()
        if let field = field.view { window.panel.makeFirstResponder(field) }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.keyDown(event) ?? false }
            return handled ? nil : event
        }
    }

    func hide() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        model.sticky = false
        model.menu = nil
        window.hide { [model] in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { model.isVisible = false }
        }
        onHide()
    }

    func escape() -> Bool {
        if model.menu != nil {
            model.menu = nil
            return true
        }
        guard !model.query.isEmpty else { return false }
        model.query = ""
        select(0)
        return true
    }

    // MARK: Keyboard

    private var list: SpotlightList {
        SpotlightList(config: store.config, states: panels.states, tab: model.tab, query: model.query)
    }

    private var pickedItem: SpotlightItem? {
        let list = list
        return list.index(of: model.selectedID, fallback: model.selected).map { list.items[$0] }
    }

    /// Picks the row at `index` in the open tab, kept in the list.
    private func select(_ index: Int, in list: SpotlightList? = nil) {
        let items = (list ?? self.list).items
        model.selected = items.isEmpty ? 0 : min(max(index, 0), items.count - 1)
        model.selectedID = items.isEmpty ? nil : items[model.selected].id
        rowKeysChanged()
    }

    static func action(_ item: SpotlightItem) -> RowAction? {
        item.kind == .row ? RowAction(url: item.url, command: item.command, title: item.title, actions: item.actions) : nil
    }

    func handle(_ key: GlanceKey) {
        guard window.isSticky else { return }
        if var menu = model.menu {
            switch key {
            case .move(.up): menu.selected = max(menu.selected - 1, 0)
            case .move(.down): menu.selected = min(menu.selected + 1, menu.commands.count - 1)
            case .activate:
                model.menu = nil
                perform(menu.commands[menu.selected].kind)
                return
            case .menu:
                model.menu = nil
                return
            default: return
            }
            model.menu = menu
            return
        }
        let list = list
        let current = list.index(of: model.selectedID, fallback: model.selected) ?? 0
        switch key {
        case .move(.up): select(current - 1, in: list)
        case .move(.down): select(current + 1, in: list)
        case .move(.left), .jump(.left), .previousTile: select(tab: model.tab - 1)
        case .move(.right), .jump(.right), .nextTile: select(tab: model.tab + 1)
        case .jump(let direction):
            // The first row of the next or previous panel's section.
            let starts = list.sections.indices.map { index in list.sections[..<index].reduce(0) { $0 + $1.items.count } }
            let section = starts.lastIndex { $0 <= current } ?? 0
            let next = direction == .down ? min(section + 1, starts.count - 1) : max(section - 1, 0)
            if starts.indices.contains(next) { select(starts[next], in: list) }
        case .tile(let number):
            if list.tabs.indices.contains(number) { select(tab: number) }
        case .activate:
            guard let item = pickedItem else { return }
            if case .more = item.kind, let tab = list.tab(of: item.tile) { return select(tab: tab) }
            if Self.action(item)?.clicks == true { perform(.click) }
        case .openURL:
            if pickedItem.flatMap(Self.action)?.hasURL == true { perform(.openURL) }
        case .runNow: perform(.refresh)
        case .openConfig: perform(.openConfig)
        case .copy:
            if pickedItem.flatMap(Self.action) != nil { perform(.copy) }
        case .action(let key):
            if let action = pickedItem?.actions.actions.first(where: { $0.key == key }) { perform(.action(action)) }
        case .menu:
            guard let item = pickedItem else { return }
            model.menu = ActionMenu(commands: GlanceCommand.all(for: Self.action(item)))
        }
        rowKeysChanged()
    }

    private func select(tab: Int) {
        let count = list.tabs.count
        model.tab = (tab + count) % count
        model.menu = nil
        select(0)
    }

    /// A click on a row: picks it, and does what a click does.
    private func pick(_ index: Int) {
        model.menu = nil
        let list = list
        select(index, in: list)
        guard let item = pickedItem else { return }
        if case .more = item.kind, let tab = list.tab(of: item.tile) { return select(tab: tab) }
        if let action = Self.action(item), action.clicks, let tile = tile(item.tile) {
            onRowAction(tile, action)
        }
    }

    private func perform(_ kind: GlanceCommand.Kind) {
        guard let item = pickedItem, let tile = tile(item.tile) else { return }
        onCommand(tile, Self.action(item), kind)
    }

    private func tile(_ id: String) -> Tile? {
        store.config.tiles.first { $0.id == id }
    }

    private func rowKeysChanged() {
        onRowKeys(pickedItem?.actions.actions.compactMap(\.key) ?? [])
    }

    /// A key while the search field has the keyboard. True when Spotlight used it; the rest go
    /// to the field.
    private func keyDown(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
        let jump = store.config.jumpKey.modifierFlags
        let code = Int(event.keyCode)
        let arrows: [Int: FocusNavigation.Direction] = [kVK_UpArrow: .up, kVK_DownArrow: .down, kVK_LeftArrow: .left, kVK_RightArrow: .right]
        if let direction = arrows[code] {
            if let jump, flags == jump {
                handle(.jump(direction))
                return true
            }
            // Left and right move the caret while there's text.
            guard flags.isEmpty, direction == .up || direction == .down || model.query.isEmpty else { return false }
            handle(.move(direction))
            return true
        }
        switch code {
        case kVK_Tab:
            handle(flags.contains(.shift) ? .previousTile : .nextTile)
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            handle(flags.contains(.option) ? .openURL : .activate)
            return true
        default:
            break
        }
        guard flags == .command, let key = event.charactersIgnoringModifiers?.lowercased() else { return false }
        // Tjuvkik has no Edit menu to send these while it's in the background.
        let editing: [String: Selector] = ["x": #selector(NSText.cut(_:)), "v": #selector(NSText.paste(_:)), "a": #selector(NSText.selectAll(_:)),
                                           "z": Selector(("undo:")), "c": #selector(NSText.copy(_:))]
        let selection = (window.panel.firstResponder as? NSTextView)?.selectedRange().length ?? 0
        if key == "c", selection > 0 || pickedItem.flatMap(Self.action) == nil {
            NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            return true
        }
        switch key {
        case "k": handle(.menu)
        case "r": handle(.runNow)
        case "o": handle(.openConfig)
        case "c": handle(.copy)
        default:
            if pickedItem?.actions.actions.contains(where: { $0.key == key }) == true {
                handle(.action(key))
            } else if let selector = editing[key] {
                NSApp.sendAction(selector, to: nil, from: nil)
            } else if let number = Int(key) {
                handle(.tile(number))
            }
        }
        // Other ⌘ keys do nothing, rather than reach the field.
        return true
    }
}

extension Config.JumpKey {
    var modifierFlags: NSEvent.ModifierFlags? {
        switch self {
        case .option: .option
        case .command: .command
        case .control: .control
        case .shift: .shift
        case .none: nil
        }
    }
}
