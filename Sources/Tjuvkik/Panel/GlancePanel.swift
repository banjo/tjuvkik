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
}

@MainActor
final class GlanceController {
    private let panel = GlancePanel()
    private let model = GlanceModel()
    private var hideGeneration = 0
    private var appearanceObservation: NSKeyValueObservation?
    private var workspaceObservers: [any NSObjectProtocol] = []
    private var outsideClicks: Any?
    private var isShown = false
    /// True while the glance stays open on its own: toggled, or pinned.
    private(set) var isSticky = false
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
    /// A tile's right-click menu.
    var tileMenu: (Tile) -> TileMenu = { _ in TileMenu() }

    init(store: ConfigStore, panels: PanelStore) {
        panel.contentView = GlanceHostingView(rootView: GlanceView(
            model: model, store: store, panels: panels,
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
        panel.setFrame(GlancePlacement.framedRect(in: screen.visibleFrame), display: false)
        panel.alphaValue = 1
        panel.ignoresMouseEvents = false
        panel.orderFrontRegardless()
        model.isVisible = true
        if sticky { stick() }
        onShow()
    }

    /// After a pin: the glance stays open until a click outside or a Space or app switch.
    func stick() {
        guard isShown, !isSticky else { return }
        isSticky = true
        stuckWhileActive = NSApp.isActive
        guard outsideClicks == nil else { return }
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
}
