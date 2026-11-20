import SwiftUI
import TjuvkikCore

/// A line of a row as the peek shows it: the same text and style, but wrapped instead of cut.
struct PeekLine {
    var text: Text
    var lineSpacing: CGFloat = 0
}

/// A row whose text is cut, as the board lays it out: what the peek shows under it.
struct PeekEntry {
    /// The whole row, in the board's coordinate space, to match the keyboard focus.
    var frame: CGRect
    /// Where the row's text starts, so the peek's text lines up with it.
    var anchor: CGRect
    var lines: [PeekLine]
    var spacing: CGFloat
    var hovering: Bool
}

struct PeekEntriesKey: PreferenceKey {
    static var defaultValue: [PeekEntry] { [] }
    static func reduce(value: inout [PeekEntry], nextValue: () -> [PeekEntry]) { value += nextValue() }
}

/// True when a text marked with `reportsTruncation()` doesn't fit.
private struct TruncatedKey: PreferenceKey {
    static var defaultValue: Bool { false }
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

private struct PeekAnchorKey: PreferenceKey {
    static var defaultValue: CGRect? { nil }
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) { value = value ?? nextValue() }
}

extension EnvironmentValues {
    /// Set while the glance shows: rows report text that's cut, for the peek.
    var peekEnabled: Bool {
        get { self[PeekEnabledKey.self] }
        set { self[PeekEnabledKey.self] = newValue }
    }
}

private struct PeekEnabledKey: EnvironmentKey {
    static var defaultValue: Bool { false }
}

extension View {
    /// Reports whether this text is cut. Goes before `lineLimit`, which it measures without.
    func reportsTruncation() -> some View {
        modifier(ReportsTruncation())
    }

    /// Where the row's text is, for the peek to line up with.
    func peekAnchor() -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: PeekAnchorKey.self, value: proxy.frame(in: .named(BoardView.space)))
            }
        }
    }

    /// Shows the lines in full under the row, on hover or keyboard focus, when its text is cut.
    func peek(_ lines: [PeekLine], spacing: CGFloat) -> some View {
        modifier(Peekable(lines: lines, spacing: spacing))
    }
}

private struct ReportsTruncation: ViewModifier {
    @Environment(\.peekEnabled) private var enabled

    func body(content: Content) -> some View {
        if enabled {
            content.background {
                GeometryReader { shown in
                    // The same text with no line limit, at the width it's shown at.
                    content
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .background {
                            GeometryReader { full in
                                Color.clear.preference(key: TruncatedKey.self, value: full.size.height > shown.size.height + 0.5)
                            }
                        }
                        .frame(width: shown.size.width, alignment: .topLeading)
                        .hidden()
                }
            }
        } else {
            content
        }
    }
}

private struct Peekable: ViewModifier {
    let lines: [PeekLine]
    let spacing: CGFloat
    @Environment(\.peekEnabled) private var enabled
    @State private var truncated = false
    @State private var anchor: CGRect?
    @State private var hovering = false

    func body(content: Content) -> some View {
        if enabled {
            content
                .onPreferenceChange(TruncatedKey.self) { value in MainActor.assumeIsolated { truncated = value } }
                .onPreferenceChange(PeekAnchorKey.self) { value in MainActor.assumeIsolated { anchor = value } }
                .transformPreference(TruncatedKey.self) { $0 = false }
                .transformPreference(PeekAnchorKey.self) { $0 = nil }
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
                .background {
                    GeometryReader { proxy in
                        let frame = proxy.frame(in: .named(BoardView.space))
                        Color.clear.preference(
                            key: PeekEntriesKey.self,
                            value: truncated ? [PeekEntry(frame: frame, anchor: anchor ?? frame, lines: lines, spacing: spacing, hovering: hovering)] : []
                        )
                    }
                }
        } else {
            // The glance closed: it gets no exit, so the hover would stick.
            content.onAppear { hovering = false }
        }
    }
}

/// Over the board: the full text of the hovered or focused row, when it's cut. It shows after a
/// moment, then at once while moving between rows, like a tooltip.
struct PeekLayer: View {
    let entries: [PeekEntry]
    /// The keyboard's focus, while it shows.
    let focus: FocusEntry?
    /// What was used last: only its row peeks.
    let input: GlanceInput
    let hidden: Bool
    let theme: Theme

    /// The row the peek shows over.
    @State private var shown: CGRect?
    /// Until then, the next peek shows at once.
    @State private var warmUntil = Date.distantPast

    private static let delay: Duration = .milliseconds(300)
    private static let warm: TimeInterval = 0.5

    var body: some View {
        let target = hidden ? nil : self.target
        ZStack {
            if let target, let shown, Self.same(shown, target.frame) {
                let padding = CGSize(width: theme.z(7), height: theme.z(4))
                PeekPlacement(
                    row: target.frame,
                    minX: target.anchor.minX - padding.width,
                    minWidth: target.anchor.width + padding.width * 2,
                    maxWidth: theme.z(440),
                    gap: theme.z(4)
                ) {
                    PeekView(entry: target, padding: padding, theme: theme)
                }
            }
        }
        .allowsHitTesting(false)
        .task(id: target?.frame) {
            guard let frame = target?.frame else {
                if shown != nil { warmUntil = Date().addingTimeInterval(Self.warm) }
                shown = nil
                return
            }
            if shown != nil || Date() < warmUntil { return shown = frame }
            try? await Task.sleep(for: Self.delay)
            if !Task.isCancelled { shown = frame }
        }
    }

    /// The hovered row after the mouse moved, the focused one after a key.
    private var target: PeekEntry? {
        let hovered = entries.first(where: \.hovering)
        guard let focus, input == .keyboard else { return hovered }
        return entries.first { Self.same($0.frame, focus.frame) }
    }

    private static func same(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 0.5 && abs(a.minY - b.minY) < 0.5 && abs(a.width - b.width) < 0.5 && abs(a.height - b.height) < 0.5
    }
}

private struct PeekView: View {
    let entry: PeekEntry
    let padding: CGSize
    let theme: Theme

    var body: some View {
        let radius = theme.z(7)
        VStack(alignment: .leading, spacing: entry.spacing) {
            ForEach(Array(entry.lines.enumerated()), id: \.offset) { _, line in
                line.text
                    .lineSpacing(line.lineSpacing)
                    .lineLimit(10)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, padding.width)
        .padding(.vertical, padding.height)
        .frame(maxWidth: .infinity, alignment: .leading)
        // A step lighter in dark themes and darker in light ones, so it reads as above the tile.
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color(theme.panel.opaque))
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color(theme.text).opacity(0.08))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color(theme.text).opacity(0.16), lineWidth: theme.z(1)))
        .shadow(color: .black.opacity(0.35), radius: theme.z(14), y: theme.z(6))
    }
}

/// Places the peek under the row, or above it when there's no room, starting where the row's text
/// does. As wide as its text up to `maxWidth` but never narrower than the row's text, and moved
/// in to stay on the board.
private struct PeekPlacement: Layout {
    let row: CGRect
    let minX: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let gap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let peek = subviews.first else { return }
        let limit = min(maxWidth, bounds.width)
        let width = min(max(peek.sizeThatFits(.unspecified).width, minWidth), limit)
        let height = peek.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        let x = min(max(minX, 0), bounds.width - width)
        let below = row.maxY + gap
        let y = below + height <= bounds.height ? below : max(row.minY - gap - height, 0)
        peek.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(width: width, height: height))
    }
}
