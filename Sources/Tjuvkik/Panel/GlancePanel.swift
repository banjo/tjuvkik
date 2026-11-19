import AppKit
import SwiftUI
import TjuvkikCore

/// The glance window: borderless, never takes focus, and shows over every Space and full-screen
/// app. It takes clicks while it shows, and lets them through while it's hidden.
final class GlancePanel: NSPanel {
    /// Before a click inside is handled, so a held glance is pinned before the click acts.
    var onMouseDown: () -> Void = {}

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

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown: onMouseDown()
        default: break
        }
        super.sendEvent(event)
    }
}

/// Acts on the first click and tracks hover although the window is never key and the app never
/// active.
final class GlanceHostingView<Content: View>: NSHostingView<Content> {
    required init(rootView: Content) {
        super.init(rootView: rootView)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
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
    /// The ⌘K list, while it's open.
    var menu: ActionMenu?
}

/// A key pressed while the glance stays open.
enum GlanceKey {
    case move(FocusNavigation.Direction)
    /// Enter or Space: what a click on the focused row does.
    case activate
    case runNow
    case openConfig
    /// 1–9: the first row of that tile on the board.
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
    private let panel = GlancePanel()
    private let model = GlanceModel()
    private let store: ConfigStore
    /// The focus targets as laid out, in board order.
    private var targets: [FocusEntry] = []
    /// Which of the targets with the same tile and action is focused, so the focus survives a
    /// panel's update.
    private var focusOrdinal = 0
    private var hideGeneration = 0
    private var appearanceObservation: NSKeyValueObservation?
    private var workspaceObservers: [any NSObjectProtocol] = []
    private var outsideClicks: Any?
    private var isShown = false
    /// True while the glance stays open on its own: toggled, or pinned.
    private(set) var isSticky = false
    /// A click outside, or between the tiles, dismisses a sticky glance.
    var closesOnClickOutside = true
    /// Tjuvkik was the active app when the glance stuck, as after setup: leaving it doesn't
    /// count as switching apps.
    private var stuckWhileActive = false

    var onShow: () -> Void = {}
    var onHide: () -> Void = {}
    var onMouseDown: () -> Void = {}
    /// A click outside, or a Space or app switch.
    var onDismiss: () -> Void = {}
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
        panel.contentView = GlanceHostingView(rootView: GlanceView(
            model: model, store: store,
            onFocusEntries: { [weak self] entries in self?.update(entries) },
            panels: panels,
            onBackgroundClick: { [weak self] in
                guard let self, self.isSticky, self.closesOnClickOutside else { return }
                self.onDismiss()
            },
            onAction: { [weak self] tile, action in self?.onRowAction(tile, action) },
            menu: { [weak self] tile in self?.tileMenu(tile) ?? TileMenu() }
        ))
        panel.onMouseDown = { [weak self] in self?.onMouseDown() }
        model.systemIsDark = Self.isDark(NSApp.effectiveAppearance)
        // KVO may call this off the main thread.
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { @Sendable [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.model.systemIsDark = Self.isDark(NSApp.effectiveAppearance)
            }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.isShown else { return }
                    self.onDismiss()
                }
            },
            workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                let isSelf = app?.processIdentifier == ProcessInfo.processInfo.processIdentifier
                MainActor.assumeIsolated {
                    guard let self, self.isSticky, !isSelf else { return }
                    if self.stuckWhileActive {
                        self.stuckWhileActive = false
                        return
                    }
                    self.onDismiss()
                }
            },
        ]
    }

    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    func show(sticky: Bool) {
        guard let screen = FocusedScreen.current() else { return }
        hideGeneration += 1
        isShown = true
        let config = store.config
        let board = BentoGeometry.board(config.grid, theme: config.theme(dark: model.systemIsDark))
        let framed = GlancePlacement.framed(
            in: screen.visibleFrame,
            content: CGSize(width: board.width, height: board.height + GlanceView.hintSpace),
            zoom: config.zoom
        )
        model.zoom = framed.zoom
        panel.setFrame(framed.rect, display: false)
        panel.alphaValue = 1
        panel.ignoresMouseEvents = false
        panel.orderFrontRegardless()
        model.isVisible = true
        focusFirst()
        if sticky { stick() }
        onShow()
    }

    /// After a pin: the glance stays open until a click outside or a Space or app switch.
    func stick() {
        guard isShown, !isSticky else { return }
        isSticky = true
        model.showsFocus = true
        stuckWhileActive = NSApp.isActive
        guard closesOnClickOutside, outsideClicks == nil else { return }
        // Only clicks that go to other apps reach a global monitor: exactly the ones outside.
        outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { @Sendable [weak self] _ in
            Task { @MainActor in
                guard let self, self.isSticky else { return }
                self.onDismiss()
            }
        }
    }

    func hide() {
        hideGeneration += 1
        isShown = false
        isSticky = false
        model.showsFocus = false
        model.menu = nil
        stuckWhileActive = false
        panel.ignoresMouseEvents = true
        if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
        outsideClicks = nil
        onHide()
        let generation = hideGeneration
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                // A show during the fade wins.
                guard generation == self.hideGeneration else { return }
                self.panel.orderOut(nil)
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { self.model.isVisible = false }
            }
        }
    }

    // MARK: Keyboard

    func handle(_ key: GlanceKey) {
        guard isSticky else { return }
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
        switch key {
        case .move(let direction):
            guard let current = focusedIndex else { return focusFirst() }
            if let next = FocusNavigation.move(from: current, direction, in: targets.map(Self.target)) { focus(next) }
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
            guard order.indices.contains(number - 1), let index = targets.firstIndex(where: { $0.tile == order[number - 1] }) else { return }
            focus(index)
        }
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
        let focusTiles = store.config.tiles.filter(\.focus).map(\.id)
        if let index = FocusNavigation.initial(targets.map(Self.target), focusTiles: focusTiles) { focus(index) } else { focusedEntry = nil }
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
        guard let previous else { return isShown ? focusFirst() : () }
        if let index = focusedIndex {
            focusedEntry = targets[index]
        } else if let index = targets.indices.filter({ targets[$0].tile == previous.tile }).min(by: {
            abs(targets[$0].frame.midY - previous.frame.midY) < abs(targets[$1].frame.midY - previous.frame.midY)
        }) {
            focus(index)
        } else {
            focusFirst()
        }
    }
}
