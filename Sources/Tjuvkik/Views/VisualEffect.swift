import AppKit
import SwiftUI
import TjuvkikCore

/// Blurs what's behind the window. SwiftUI materials only blur within the window.
struct VisualEffect: NSViewRepresentable {
    var cornerRadius: CGFloat
    var appearance: Theme.Appearance

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.layer?.cornerRadius = cornerRadius
        view.appearance = appearance.nsAppearance
    }
}
