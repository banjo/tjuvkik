import AppKit
import SwiftUI

/// Scrolling a tile's list a whole item at a time, so no item is ever cut in half: the glance
/// keeps how many items each tile skips at its top, a `FittingStack` leaves those out, and every
/// item reports whether it's shown, so the glance knows what's left below.
extension EnvironmentValues {
    /// How many list items the tile skips at its top.
    var tileScroll: Int {
        get { self[TileScrollKey.self] }
        set { self[TileScrollKey.self] = newValue }
    }

    /// Set by the glance: scrolls the tile by that many items, down when positive.
    var scrollTile: ((Int) -> Void)? {
        get { self[ScrollTileKey.self] }
        set { self[ScrollTileKey.self] = newValue }
    }
}

private struct TileScrollKey: EnvironmentKey {
    static var defaultValue: Int { 0 }
}

private struct ScrollTileKey: EnvironmentKey {
    static var defaultValue: ((Int) -> Void)? { nil }
}

/// Which list item a `FittingStack` child belongs to. A heading or note has its item's index, so
/// it scrolls away with it. Children without one, like a hero number, always stay.
struct ScrollItemKey: LayoutValueKey {
    static let defaultValue: Int? = nil
}

/// A list item as laid out: whether it's shown, or left out above or below.
struct ScrollItem: Equatable {
    var tile: String
    var index: Int
    var shown: Bool
}

struct ScrollItemsKey: PreferenceKey {
    static var defaultValue: [ScrollItem] { [] }
    static func reduce(value: inout [ScrollItem], nextValue: () -> [ScrollItem]) { value += nextValue() }
}

/// What a tile's list has out of view, for the glance's scrolling and its "↓ 3" hint.
struct TileScrollState: Equatable {
    /// Items skipped at the top.
    var above = 0
    /// Items that don't fit below the last shown one.
    var below = 0

    /// One per tile, from the items its lists reported.
    static func states(_ items: [ScrollItem], scroll: [String: Int]) -> [String: TileScrollState] {
        Dictionary(grouping: items, by: \.tile).mapValues { items in
            let count = (items.map(\.index).max() ?? -1) + 1
            // An item is shown when all of it is: a heading without its row isn't.
            let last = Dictionary(grouping: items, by: \.index).filter { $0.value.allSatisfy(\.shown) }.keys.max()
            let skipped = scroll[items[0].tile] ?? 0
            return TileScrollState(above: min(skipped, count), below: last.map { count - 1 - $0 } ?? max(count - skipped, 0))
        }
    }
}

extension View {
    /// Marks a child of a `FittingStack` as part of list item `index`, so the tile can scroll it.
    func scrollItem(_ index: Int) -> some View {
        modifier(ScrollItemReport(index: index)).layoutValue(key: ScrollItemKey.self, value: index)
    }

    /// Nil leaves it out of scrolling, for a list that doesn't scroll in this layout.
    @ViewBuilder func scrollItem(_ index: Int?) -> some View {
        if let index { scrollItem(index) } else { self }
    }

    /// Scrolls the tile with the trackpad or mouse wheel, an item per notch or swipe step, while
    /// clicks go through to what's under it.
    func scrollsWithWheel(step: CGFloat) -> some View {
        modifier(WheelScrolling(step: step))
    }
}

private struct ScrollItemReport: ViewModifier {
    let index: Int
    @Environment(\.focusTile) private var tile

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                // A FittingStack puts what it leaves out far off to the top left, at no size.
                let frame = proxy.frame(in: .named(BoardView.space))
                Color.clear.preference(
                    key: ScrollItemsKey.self,
                    value: tile.map { [ScrollItem(tile: $0, index: index, shown: frame.minX > -5_000 && frame.height > 0)] } ?? []
                )
            }
        }
    }
}

private struct WheelScrolling: ViewModifier {
    let step: CGFloat
    @Environment(\.scrollTile) private var scrollTile

    func body(content: Content) -> some View {
        if let scrollTile {
            content.overlay(WheelCatcher(step: step, onScroll: scrollTile))
        } else {
            content
        }
    }
}

/// Catches only scroll wheel events: every other event goes to the views below.
private struct WheelCatcher: NSViewRepresentable {
    let step: CGFloat
    let onScroll: (Int) -> Void

    func makeNSView(context: Context) -> WheelCatcherView {
        WheelCatcherView()
    }

    func updateNSView(_ view: WheelCatcherView, context: Context) {
        view.step = step
        view.onScroll = onScroll
    }
}

final class WheelCatcherView: NSView {
    var step: CGFloat = 24
    var onScroll: (Int) -> Void = { _ in }
    /// Scrolled but not yet a whole item.
    private var pending: CGFloat = 0

    override func hitTest(_ point: NSPoint) -> NSView? {
        NSApp.currentEvent?.type == .scrollWheel ? super.hitTest(point) : nil
    }

    override func scrollWheel(with event: NSEvent) {
        if event.phase == .began || event.phase == .mayBegin { pending = 0 }
        // A mouse wheel moves in lines, a trackpad in points: a notch is an item.
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * step
        // Up on the wheel, or down with natural scrolling, shows what's above.
        pending -= delta
        var items = 0
        while pending >= step { pending -= step; items += 1 }
        while pending <= -step { pending += step; items -= 1 }
        if items != 0 { onScroll(items) }
    }
}
