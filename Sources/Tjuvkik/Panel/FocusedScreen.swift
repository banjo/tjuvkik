import AppKit
import TjuvkikCore

/// The screen of the focused window: the frontmost app's topmost normal window. Window bounds
/// need no permission, only window titles do. Falls back to the screen with the mouse.
@MainActor
enum FocusedScreen {
    static func current() -> NSScreen? {
        let screens = NSScreen.screens
        if let window = frontmostWindowFrame(),
           let index = GlancePlacement.screenIndex(for: window, screens: screens.map(\.frame)) {
            return screens[index]
        }
        let mouse = NSEvent.mouseLocation
        return screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    }

    private static func frontmostWindowFrame() -> CGRect? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let primary = NSScreen.screens.first,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return nil }

        // The list is ordered front to back.
        for info in list {
            guard info[kCGWindowOwnerPID as String] as? pid_t == pid,
                  info[kCGWindowLayer as String] as? Int == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.width > 50, bounds.height > 50
            else { continue }
            return GlancePlacement.appKitRect(fromQuartz: bounds, primaryScreenHeight: primary.frame.height)
        }
        return nil
    }
}
