import AppKit
import CoreGraphics

/// The Input Monitoring permission, which a listen-only event tap needs.
enum InputMonitoring {
    static var isGranted: Bool { CGPreflightListenEventAccess() }

    /// Shows the system prompt the first time; later calls do nothing.
    static func request() {
        CGRequestListenEventAccess()
    }

    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }
}
