import AppKit
import SwiftUI
import TjuvkikCore

/// Blurs what's behind the window. SwiftUI materials only blur within the window.
struct VisualEffect: NSViewRepresentable {
    var cornerRadius: CGFloat
    var appearance: Theme.Appearance
    var material: Theme.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material.nsMaterial
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
        view.material = material.nsMaterial
    }
}

extension Theme.Material {
    var nsMaterial: NSVisualEffectView.Material {
        switch self {
        case .hud: .hudWindow
        case .popover: .popover
        case .menu: .menu
        case .sidebar: .sidebar
        case .underWindow: .underWindowBackground
        }
    }
}
