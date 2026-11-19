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

    /// The screen width `"zoom": "auto"` draws the board at zoom 1 on, a 16-inch MacBook Pro's.
    /// Wider screens zoom in, up to `autoZoomLimit`; narrower ones stay at 1.
    public static let autoZoomWidth: CGFloat = 1728
    public static let autoZoomLimit: CGFloat = 1.5

    public struct Framed: Equatable, Sendable {
        /// The glance's window: the board and what's below it.
        public var rect: CGRect
        public var zoom: CGFloat
    }

    /// The Framed glance: centered, 13% down from the top of the usable area. `content` is the
    /// board and what's below it at zoom 1. The zoom is the one asked for, made smaller when the
    /// glance wouldn't fit.
    public static func framed(in visibleFrame: CGRect, content: CGSize, zoom: Config.Zoom) -> Framed {
        let wanted: CGFloat = switch zoom {
        case .auto: min(max(visibleFrame.width / autoZoomWidth, 1), autoZoomLimit)
        case .fixed(let value): CGFloat(value)
        }
        let fitsWidth = (visibleFrame.width - 48) / content.width
        let fitsHeight = (visibleFrame.height * 0.87 - 24) / content.height
        let scale = min(wanted, fitsWidth, fitsHeight)
        let width = (content.width * scale).rounded(), height = (content.height * scale).rounded()
        let top = visibleFrame.maxY - visibleFrame.height * 0.13
        return Framed(
            rect: CGRect(x: (visibleFrame.midX - width / 2).rounded(), y: (top - height).rounded(), width: width, height: height),
            zoom: scale
        )
    }
}
