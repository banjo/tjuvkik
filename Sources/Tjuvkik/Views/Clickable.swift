import SwiftUI
import TjuvkikCore

/// What clicking a row does, and what else the keyboard can do with it.
struct RowAction: Equatable {
    var url: String?
    var command: String?
    /// What ⌘C copies when there's no url.
    var title = ""
    var actions = RowActions()

    var hasCommand: Bool { !(command ?? "").isEmpty }
    var hasURL: Bool { !(url ?? "").isEmpty }
    /// A click does something.
    var clicks: Bool { hasCommand || hasURL }
    var isEmpty: Bool { !clicks && actions.actions.isEmpty }
}

extension EnvironmentValues {
    /// Set by the glance. Nil elsewhere (previews, the settings window), where rows don't click.
    var performRow: ((RowAction) -> Void)? {
        get { self[PerformRowKey.self] }
        set { self[PerformRowKey.self] = newValue }
    }

    /// The tile a row is in, for the keyboard focus.
    var focusTile: String? {
        get { self[FocusTileKey.self] }
        set { self[FocusTileKey.self] = newValue }
    }
}

// `@Entry` needs SwiftUI's macro plugin, which the command line tools don't have.
private struct PerformRowKey: EnvironmentKey {
    static var defaultValue: ((RowAction) -> Void)? { nil }
}

private struct FocusTileKey: EnvironmentKey {
    static var defaultValue: String? { nil }
}

/// A clickable row or a whole tile, as the board lays it out: what the keyboard can focus.
struct FocusEntry: Equatable {
    /// In the board's coordinate space.
    var frame: CGRect
    var tile: String
    var tone: Tone?
    /// Nil for a whole tile.
    var action: RowAction?
    var radius: CGFloat

    var urgency: Int {
        switch tone {
        case .error: 2
        case .warning: 1
        default: 0
        }
    }
}

struct FocusEntriesKey: PreferenceKey {
    static var defaultValue: [FocusEntry] { [] }
    static func reduce(value: inout [FocusEntry], nextValue: () -> [FocusEntry]) { value += nextValue() }
}

extension View {
    /// Highlights on hover and performs the action on click, when there's one and the glance takes clicks.
    /// `tone` makes an error or warning row the first the keyboard focuses.
    func clickable(_ action: RowAction, theme: Theme, radius: CGFloat? = nil, tone: Tone? = nil) -> some View {
        modifier(ClickableRow(action: action, theme: theme, radius: radius ?? theme.z(6), tone: tone))
    }

    /// Reports this view's frame on the board as something the keyboard can focus.
    func focusEntry(tile: String, tone: Tone? = nil, action: RowAction?, radius: CGFloat) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: FocusEntriesKey.self,
                    value: [FocusEntry(frame: proxy.frame(in: .named(BoardView.space)), tile: tile, tone: tone, action: action, radius: radius)]
                )
            }
        }
    }
}

private struct ClickableRow: ViewModifier {
    let action: RowAction
    let theme: Theme
    let radius: CGFloat
    let tone: Tone?
    @Environment(\.performRow) private var perform
    @Environment(\.focusTile) private var tile
    @State private var hovering = false

    func body(content: Content) -> some View {
        if let perform, action.clicks {
            content
                .contentShape(Rectangle())
                .background(hovering ? Color(theme.well) : .clear, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .onHover { hovering = $0 }
                .onTapGesture { perform(action) }
                .pointerStyle(.link)
                .focusEntry(tile: tile ?? "", tone: tone, action: action, radius: radius)
        } else if perform != nil, !action.isEmpty {
            // Only actions: the keyboard can pick it for ⌘K, but a click does nothing.
            content.focusEntry(tile: tile ?? "", tone: tone, action: action, radius: radius)
        } else {
            content
        }
    }
}
