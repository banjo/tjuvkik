import AppKit
import SwiftUI
import TjuvkikCore

/// The glance window: borderless, never takes focus, lets clicks through, and shows over every
/// Space and full-screen app.
final class GlancePanel: NSPanel {
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
}

@MainActor
@Observable
final class GlanceModel {
    var isVisible = false
}

@MainActor
final class GlanceController {
    private let panel = GlancePanel()
    private let model = GlanceModel()
    private var hideGeneration = 0

    init(store: ConfigStore) {
        panel.contentView = NSHostingView(rootView: GlanceView(model: model, store: store))
    }

    func show() {
        guard let screen = FocusedScreen.current() else { return }
        hideGeneration += 1
        panel.setFrame(GlancePlacement.framedRect(in: screen.visibleFrame), display: false)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        model.isVisible = true
    }

    func hide() {
        hideGeneration += 1
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
