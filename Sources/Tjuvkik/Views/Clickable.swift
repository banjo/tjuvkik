import SwiftUI
import TjuvkikCore

/// What clicking a row does.
struct RowAction: Equatable {
    var url: String?
    var command: String?
    var isEmpty: Bool { (url ?? "").isEmpty && (command ?? "").isEmpty }
}

extension EnvironmentValues {
    /// Set by the glance. Nil elsewhere (previews, the settings window), where rows don't click.
    var performRow: ((RowAction) -> Void)? {
        get { self[PerformRowKey.self] }
        set { self[PerformRowKey.self] = newValue }
    }
}

// `@Entry` needs SwiftUI's macro plugin, which the command line tools don't have.
private struct PerformRowKey: EnvironmentKey {
    static var defaultValue: ((RowAction) -> Void)? { nil }
}

extension View {
    /// Highlights on hover and performs the action on click, when there's one and the glance takes clicks.
    func clickable(_ action: RowAction, theme: Theme, radius: CGFloat = 6) -> some View {
        modifier(ClickableRow(action: action, theme: theme, radius: radius))
    }
}

private struct ClickableRow: ViewModifier {
    let action: RowAction
    let theme: Theme
    let radius: CGFloat
    @Environment(\.performRow) private var perform
    @State private var hovering = false

    func body(content: Content) -> some View {
        if let perform, !action.isEmpty {
            content
                .contentShape(Rectangle())
                .background(hovering ? Color(theme.well) : .clear, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .onHover { hovering = $0 }
                .onTapGesture { perform(action) }
                .pointerStyle(.link)
        } else {
            content
        }
    }
}
