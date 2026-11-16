import CoreGraphics

/// Where the glance goes. All rects are in AppKit coordinates (origin bottom-left of the primary
/// screen) unless the name says Quartz.
public enum GlancePlacement {
    /// Converts a Quartz rect (origin top-left of the primary screen, as `CGWindowListCopyWindowInfo`
    /// reports window bounds) to AppKit coordinates.
    public static func appKitRect(fromQuartz rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// The index of the screen that a window overlaps most, or nil if it is on none of them.
    public static func screenIndex(for window: CGRect, screens: [CGRect]) -> Int? {
        let areas = screens.map { screen -> CGFloat in
            let overlap = screen.intersection(window)
            return overlap.isNull ? 0 : overlap.width * overlap.height
        }
        guard let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 else { return nil }
        return best
    }

    /// The Framed glance: centered, 13% down from the top of the usable area, at most 1080×580.
    public static func framedRect(in visibleFrame: CGRect) -> CGRect {
        let width = min(1080, visibleFrame.width - 48)
        let height = min(580, visibleFrame.height * 0.66)
        let top = visibleFrame.maxY - visibleFrame.height * 0.13
        return CGRect(
            x: (visibleFrame.midX - width / 2).rounded(),
            y: (top - height).rounded(),
            width: width.rounded(),
            height: height.rounded()
        )
    }
}
