import AppKit
import SwiftUI
import TjuvkikCore

/// The glance window: borderless, and shows over every Space and full-screen app. It takes clicks
/// while it shows, and lets them through while it's hidden. It never activates Tjuvkik, and takes
/// keyboard focus only while `takesKeyboard`, for Spotlight's search field.
final class GlancePanel: NSPanel {
    /// Before a click inside is handled, so a held glance is pinned before the click acts.
    var onMouseDown: () -> Void = {}
    var takesKeyboard = false

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isFloatingPanel = true
        ignoresMouseEvents = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { takesKeyboard }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown: onMouseDown()
        default: break
        }
        super.sendEvent(event)
    }
}

/// Darkens the screen behind the glance, for `"dim"`. Clicks go through it.
final class DimWindow: NSWindow {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .black
        hasShadow = false
        ignoresMouseEvents = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        animationBehavior = .none
        alphaValue = 0
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Acts on the first click and tracks hover although the window is never key and the app never
/// active.
final class GlanceHostingView<Content: View>: NSHostingView<Content> {
    /// The pointer moved: not rows scrolling under it.
    var onMouseMoved: () -> Void = {}

    required init(rootView: Content) {
        super.init(rootView: rootView)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onMouseMoved()
    }
}

/// The mouse or the keyboard, whichever was used last in the glance.
enum GlanceInput {
    case mouse, keyboard
}

@MainActor
@Observable
final class GlanceModel {
    var isVisible = false
    var systemIsDark = false
    /// How much bigger than at zoom 1 the glance draws, for the screen it's on.
    var zoom: CGFloat = 1
    /// What the keyboard has focused, and whether it shows: only while the glance stays open.
    var focused: FocusEntry?
    var showsFocus = false
    var input = GlanceInput.keyboard
    /// The ⌘K list, while it's open.
    var menu: ActionMenu?
    /// List items each tile has scrolled away at its top, while the glance is open.
    var scroll: [String: Int] = [:]
    /// What each tile's list has out of view, above and below.
    var scrollStates: [String: TileScrollState] = [:]
}

/// A key pressed while the glance stays open.
enum GlanceKey {
    case move(FocusNavigation.Direction)
    /// The jump key and an arrow: the next tile that way.
    case jump(FocusNavigation.Direction)
    /// Tab and ⇧Tab: the next and previous tile, in `panels` order.
    case nextTile
    case previousTile
    /// Enter or Space: what a click on the focused row does.
    case activate
    case runNow
    case openConfig
    /// 1–9: that tile on the board.
    case tile(Int)
    /// ⌘K: the focused row's commands.
    case menu
    case copy
    /// ⌥↵: the row's url, though it has a command.
    case openURL
    /// ⌘ and a letter or digit: the row's action with that `key`.
    case action(String)
}

@MainActor
final class GlanceController {
    private var window: GlanceWindow!
    private let model = GlanceModel()
    private let store: ConfigStore
    /// The focus targets as laid out, in board order.
    private var targets: [FocusEntry] = []
    /// Which of the targets with the same tile and action is focused, so the focus survives a
    /// panel's update.
    private var focusOrdinal = 0
    /// A tile the keyboard just scrolled: once it's laid out again, the focus goes to the row
    /// that came into view.
    private var scrolledByKey: (tile: String, direction: FocusNavigation.Direction)?
    /// The focus when the glance last closed, for `"focusOnOpen": "last"`.
    private var lastFocus: (entry: FocusEntry, ordinal: Int)?
    /// The row last focused in each tile, so jumping back to a tile lands on it.
    private var tileFocus: [String: (entry: FocusEntry, ordinal: Int)] = [:]
    /// Where the pointer was when the keyboard last took over.
    private var keyboardMouse: CGPoint?
    private var isShown: Bool { window.isShown }
    /// True while the glance stays open on its own: toggled, or pinned.
    var isSticky: Bool { window.isSticky }
    /// A click outside, or between the tiles, dismisses a sticky glance.
    var closesOnClickOutside: Bool {
        get { window.closesOnClickOutside }
        set { window.closesOnClickOutside = newValue }
    }

    var onShow: () -> Void = {}
    var onHide: () -> Void = {}
    var onMouseDown: () -> Void = {}
    /// A click outside, or a Space or app switch.
    var onDismiss: () -> Void = {} {
        didSet { window.onDismiss = onDismiss }
    }
    /// A click on a row with a `url` or `command`.
    var onRowAction: (Tile, RowAction) -> Void = { _, _ in }
    /// A keyboard command on the focused row, or its tile when the row is nil.
    var onCommand: (Tile, RowAction?, GlanceCommand.Kind) -> Void = { _, _, _ in }
    /// The `key`s of the focused row's actions, to take with ⌘ while it's focused.
    var onRowKeys: ([String]) -> Void = { _ in }
    /// A tile's right-click menu.
    var tileMenu: (Tile) -> TileMenu = { _ in TileMenu() }

    init(store: ConfigStore, panels: PanelStore) {
        self.store = store
        let hosting = GlanceHostingView(rootView: GlanceView(
            model: model, store: store,
            onFocusEntries: { [weak self] entries in self?.update(entries) },
            onScrollItems: { [weak self] items in self?.update(items) },
            onScroll: { [weak self] tile, items in _ = self?.scroll(tile, by: items) },
            panels: panels,
            onBackgroundClick: { [weak self] in
                guard let self, self.isSticky, self.closesOnClickOutside else { return }
                self.onDismiss()
            },
            onAction: { [weak self] tile, action in self?.onRowAction(tile, action) },
            menu: { [weak self] tile in self?.tileMenu(tile) ?? TileMenu() }
        ))
        // AppKit also sends moves when the view redraws under a still pointer: those don't count.
        // Set only when it changes: each set redraws the glance.
        hosting.onMouseMoved = { [weak self] in
            guard let self, model.input != .mouse, NSEvent.mouseLocation != keyboardMouse else { return }
            model.input = .mouse
        }
        window = GlanceWindow(content: hosting)
        window.panel.onMouseDown = { [weak self] in self?.onMouseDown() }
        window.onAppearanceChange = { [model] dark in model.systemIsDark = dark }
        model.systemIsDark = window.systemIsDark
    }

    func show(sticky: Bool) {
        guard let screen = FocusedScreen.current() else { return }
        let config = store.config
        let board = BentoGeometry.board(config.grid, theme: config.theme(dark: model.systemIsDark))
        let framed = GlancePlacement.framed(
            in: screen.visibleFrame,
            content: CGSize(width: board.width, height: board.height + GlanceView.hintSpace),
            zoom: config.zoom
        )
        model.zoom = framed.zoom
        window.show(framed.rect, on: screen, dim: config.dim)
        model.isVisible = true
        useKeyboard()
        focusFirst()
        if sticky { stick() }
        onShow()
    }

    /// After a pin: the glance stays open until a click outside or a Space or app switch.
    func stick() {
        guard window.stick() else { return }
        model.showsFocus = true
    }

    func hide() {
        if isShown, let focused = model.focused { lastFocus = (focused, focusOrdinal) }
        model.showsFocus = false
        model.menu = nil
        model.scroll = [:]
        scrolledByKey = nil
        window.hide { [model] in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { model.isVisible = false }
        }
        onHide()
    }

    // MARK: Keyboard

    func handle(_ key: GlanceKey) {
        guard isSticky else { return }
        useKeyboard()
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
        scrolledByKey = nil
        if let focused = model.focused { tileFocus[focused.tile] = (focused, focusOrdinal) }
        switch key {
        case .move(let direction):
            guard let current = focusedIndex else { return focusFirst() }
            let tile = targets[current].tile
            let next = FocusNavigation.move(from: current, direction, in: targets.map(Self.target))
            // At the end of what a tile shows: scroll its list before leaving it.
            if direction == .down || direction == .up, next.map({ targets[$0].tile != tile }) ?? true,
               scroll(tile, by: direction == .down ? 1 : -1) {
                scrolledByKey = (tile, direction)
                return
            }
            if let next { focus(next) }
        case .activate:
            if model.focused?.action?.clicks == true { perform(.click) }
        case .runNow: perform(.refresh)
        case .openConfig: perform(.openConfig)
        case .copy: perform(.copy)
        case .openURL:
            if model.focused?.action?.hasURL == true { perform(.openURL) }
        case .action(let key):
            if let action = model.focused?.action?.actions.actions.first(where: { $0.key == key }) { perform(.action(action)) }
        case .menu:
            guard let focused = model.focused else { return }
            model.menu = ActionMenu(commands: GlanceCommand.all(for: focused.action))
        case .tile(let number):
            let order = tileOrder
            guard order.indices.contains(number - 1) else { return }
            focus(tile: order[number - 1])
        case .nextTile, .previousTile:
            let order = tileOrder.filter { tile in targets.contains { $0.tile == tile } }
            guard !order.isEmpty else { return }
            let step = if case .nextTile = key { 1 } else { -1 }
            guard let current = model.focused.flatMap({ order.firstIndex(of: $0.tile) }) else { return focus(tile: order[0]) }
            focus(tile: order[(current + step + order.count) % order.count])
        case .jump(let direction):
            guard let current = model.focused?.tile else { return focusFirst() }
            let tiles = store.config.tiles.compactMap { tile in
                tile.slot.map { FocusNavigation.Target(frame: CGRect(x: $0.column, y: $0.row, width: $0.columns, height: $0.rows), tile: tile.id) }
            }.filter { tile in targets.contains { $0.tile == tile.tile } }
            guard let from = tiles.firstIndex(where: { $0.tile == current }),
                  let next = FocusNavigation.move(from: from, direction, in: tiles) else { return }
            focus(tile: tiles[next].tile)
        }
    }

    /// The keyboard leads until the pointer moves away from where it is now.
    private func useKeyboard() {
        keyboardMouse = NSEvent.mouseLocation
        if model.input != .keyboard { model.input = .keyboard }
    }

    /// Esc closes the ⌘K list first. True when it did.
    func escape() -> Bool {
        guard model.menu != nil else { return false }
        model.menu = nil
        return true
    }

    private func perform(_ kind: GlanceCommand.Kind) {
        guard let focused = model.focused, let tile = tile(focused.tile) else { return }
        onCommand(tile, focused.action, kind)
    }

    private func tile(_ id: String) -> Tile? {
        store.config.tiles.first { $0.id == id }
    }

    /// The tiles on the board, in config order.
    private var tileOrder: [String] {
        store.config.tiles.filter { $0.slot != nil }.map(\.id)
    }

    private static func target(_ entry: FocusEntry) -> FocusNavigation.Target {
        FocusNavigation.Target(frame: entry.frame, tile: entry.tile, urgency: entry.urgency)
    }

    private func focusFirst() {
        if store.config.focusOnOpen == .last, let last = lastFocus, let index = index(like: last.entry, ordinal: last.ordinal) {
            return focus(index)
        }
        let focusTiles = store.config.tiles.filter(\.focus).map(\.id)
        if let index = FocusNavigation.initial(targets.map(Self.target), focusTiles: focusTiles) { focus(index) } else { focusedEntry = nil }
    }

    /// The row last focused in the tile, or its first.
    private func focus(tile: String) {
        let remembered = tileFocus[tile].flatMap { index(like: $0.entry, ordinal: $0.ordinal) }
        if let index = remembered ?? targets.firstIndex(where: { $0.tile == tile }) { focus(index) }
    }

    private func focus(_ index: Int) {
        let entry = targets[index]
        focusOrdinal = targets[..<index].count { $0.tile == entry.tile && $0.action == entry.action }
        focusedEntry = entry
    }

    private var focusedEntry: FocusEntry? {
        get { model.focused }
        set {
            if newValue?.tile != model.focused?.tile || newValue?.action != model.focused?.action { model.menu = nil }
            model.focused = newValue
            onRowKeys(newValue?.action?.actions.actions.compactMap(\.key) ?? [])
        }
    }

    private var focusedIndex: Int? {
        guard let focused = model.focused else { return nil }
        return targets.indices.filter { targets[$0].tile == focused.tile && targets[$0].action == focused.action }.dropFirst(focusOrdinal).first
    }

    /// The same row, or the nearest one in its tile when it changed.
    private func index(like entry: FocusEntry, ordinal: Int) -> Int? {
        let inTile = targets.indices.filter { targets[$0].tile == entry.tile }
        if let same = inTile.filter({ targets[$0].action == entry.action }).dropFirst(ordinal).first { return same }
        return inTile.min { abs(targets[$0].frame.midY - entry.frame.midY) < abs(targets[$1].frame.midY - entry.frame.midY) }
    }

    // MARK: Scrolling

    /// Scrolls a tile's list by that many items, down when positive, as far as it goes. False
    /// when it can't move that way.
    @discardableResult
    func scroll(_ tile: String, by items: Int) -> Bool {
        var state = model.scrollStates[tile] ?? TileScrollState()
        let moved = items > 0 ? min(items, state.below) : -min(-items, state.above)
        guard moved != 0 else { return false }
        let skipped = (model.scroll[tile] ?? 0) + moved
        model.scroll[tile] = skipped == 0 ? nil : skipped
        // Until the tile is laid out again, so a fast swipe doesn't scroll past the end.
        state.above += moved
        state.below -= moved
        model.scrollStates[tile] = state
        return true
    }

    /// New layout of the tiles' lists: what each has out of view. A list that got shorter is
    /// scrolled back so it isn't empty.
    private func update(_ items: [ScrollItem]) {
        let states = TileScrollState.states(items, scroll: model.scroll)
        for (tile, skipped) in model.scroll {
            let count = items.filter { $0.tile == tile }.map(\.index).max().map { $0 + 1 } ?? 0
            if skipped >= count { model.scroll[tile] = count > 1 ? count - 1 : nil }
        }
        if states != model.scrollStates { model.scrollStates = states }
    }

    /// New layout: tiles in config order, each one's rows top to bottom, or the tile itself when
    /// it has none in view. The focus stays on its row, or moves to the nearest in its tile.
    private func update(_ entries: [FocusEntry]) {
        var ordered: [FocusEntry] = []
        for id in tileOrder {
            guard let whole = entries.first(where: { $0.tile == id && $0.action == nil }) else { continue }
            // Rows cut off at the tile's bottom can't be seen, so they can't be picked.
            let rows = entries
                .filter { $0.tile == id && $0.action != nil && whole.frame.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }
                .sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
            ordered += rows.isEmpty ? [whole] : rows
        }
        guard ordered != targets else { return }
        let previous = model.focused
        targets = ordered
        // Scrolled by the keyboard: on to the row that came into view.
        if let scrolled = scrolledByKey {
            scrolledByKey = nil
            let inTile = targets.indices.filter { targets[$0].tile == scrolled.tile }
            if let index = scrolled.direction == .down ? inTile.last : inTile.first { return focus(index) }
        }
        guard let previous else { return isShown ? focusFirst() : () }
        if let index = focusedIndex {
            focusedEntry = targets[index]
        } else if let index = index(like: previous, ordinal: focusOrdinal) {
            focus(index)
        } else {
            focusFirst()
        }
    }
}
