import SwiftUI
import TjuvkikCore

/// Notes, runbooks, answers. s shows the heading and the first lines, m flows into two columns,
/// l the whole document. Whole blocks only: what doesn't fit is cut.
struct MarkdownView: View {
    let content: MarkdownContent
    let size: TileSize
    let theme: Theme

    var body: some View {
        let layout = TileLayout(size)
        let pieces = Self.pieces(content.blocks, titleLevel: content.titleLevel)
        MarkdownFlowLayout(columns: layout == .m ? 2 : 1) {
            ForEach(Array(pieces.enumerated()), id: \.offset) { index, piece in
                pieceView(piece, compact: layout == .s, tint: nil)
                    .layoutValue(key: PieceSpacing.self, value: index == 0 ? 0 : Self.spacing(after: pieces[index - 1], before: piece))
                    .layoutValue(key: KeepWithNext.self, value: piece.isHeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Pieces

    /// A block as the tile places it: each list item on its own, so a list is cut between items.
    fileprivate enum Piece {
        case title(String)
        case section(String)
        case paragraph(String)
        case item(MarkdownListItem, last: Bool)
        case code(String)
        case quote([Piece])
        case rule

        var isHeading: Bool {
            switch self {
            case .title, .section: true
            case .paragraph, .item, .code, .quote, .rule: false
            }
        }

        /// Its margins in the prototype, top and bottom. Between two pieces the larger one counts.
        var margins: (top: CGFloat, bottom: CGFloat) {
            switch self {
            case .title: (0, 4)
            case .section: (10, 3)
            case .paragraph: (0, 6)
            case .item(_, let last): (1, last ? 6 : 1)
            case .code, .quote: (4, 8)
            case .rule: (6, 6)
            }
        }
    }

    private static func pieces(_ blocks: [MarkdownBlock], titleLevel: Int?) -> [Piece] {
        blocks.flatMap { block -> [Piece] in
            switch block {
            case .heading(let level, let text): [level == titleLevel ? Piece.title(text) : Piece.section(text)]
            case .paragraph(let text): [.paragraph(text)]
            case .list(let items): items.enumerated().map { index, item in Piece.item(item, last: index == items.count - 1) }
            case .code(_, let text): [.code(text)]
            case .quote(let inner): [Piece.quote(pieces(inner, titleLevel: titleLevel))]
            case .rule: [.rule]
            }
        }
    }

    private static func spacing(after previous: Piece, before piece: Piece) -> CGFloat {
        max(previous.margins.bottom, piece.margins.top)
    }

    // MARK: Drawing

    /// One piece. In a quote, `tint` is the warning color, and text takes it instead of its own.
    @ViewBuilder private func pieceView(_ piece: Piece, compact: Bool, tint: Color?) -> some View {
        switch piece {
        case .title(let text):
            let size: CGFloat = compact ? 15 : 14
            Text(inline(text, size: size, weight: .semibold, color: tint ?? Color(theme.text), tint: tint))
                .tracking(-0.01 * size)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .section(let text):
            Text(inline(text.uppercased(), size: 10.5, weight: .semibold, color: tint ?? Color(theme.tertiaryText), tint: tint))
                .tracking(0.63)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .paragraph(let text):
            Text(inline(text, size: 12.5, color: tint ?? Color(theme.secondaryText), tint: tint))
                .lineSpacing(3.5)
                .lineLimit(compact ? 4 : nil)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .item(let item, _):
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                marker(item, tint: tint)
                    .frame(width: 14, alignment: .trailing)
                Text(inline(item.text, size: 12.5, color: itemColor(item, tint: tint), tint: tint))
                    .lineSpacing(3.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, CGFloat(item.depth) * 18)
        case .code(let text):
            VStack(alignment: .leading, spacing: 5.75) {
                ForEach(Array(text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, line in
                    Text(line.isEmpty ? " " : String(line))
                        .font(theme.font(11.5, mono: true))
                        .foregroundStyle(tint ?? Color(theme.text))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .well(theme, radius: 8)
        case .quote(let inner):
            quote(inner, compact: compact)
        case .rule:
            Rectangle()
                .fill(Color(theme.line))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
    }

    /// A blockquote, in the warning tone with a bar on its left.
    private func quote(_ inner: [Piece], compact: Bool) -> AnyView {
        let warning = Color(theme.warning)
        return AnyView(VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(inner.enumerated()), id: \.offset) { _, piece in
                // A quote in a quote is drawn as one quote.
                if case .quote(let nested) = piece {
                    ForEach(Array(nested.enumerated()), id: \.offset) { _, piece in
                        AnyView(pieceView(piece, compact: compact, tint: warning))
                    }
                } else {
                    AnyView(pieceView(piece, compact: compact, tint: warning))
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background(for: .warning, color: warning, opacity: 0.12))
        .overlay(alignment: .leading) { Rectangle().fill(warning).frame(width: 2) }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)))
    }

    @ViewBuilder private func marker(_ item: MarkdownListItem, tint: Color?) -> some View {
        if let checked = item.checked {
            Text(Image(systemName: checked ? "checkmark.square.fill" : "square"))
                .font(theme.font(11.5))
                .foregroundStyle(checked ? Color(theme.success) : (tint ?? Color(theme.tertiaryText)))
        } else {
            switch item.marker {
            case .bullet:
                Text(item.depth == 0 ? "•" : "◦")
                    .font(theme.font(12.5))
                    .foregroundStyle(tint ?? Color(theme.tertiaryText))
            case .number(let number):
                Text("\(number).")
                    .font(theme.font(12.5).monospacedDigit())
                    .foregroundStyle(tint ?? Color(theme.tertiaryText))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    /// A done task fades.
    private func itemColor(_ item: MarkdownListItem, tint: Color?) -> Color {
        if let tint { return tint }
        return item.checked == true ? Color(theme.tertiaryText) : Color(theme.secondaryText)
    }

    /// Inline Markdown: bold in the text color, italics, `code` on the well, links in the info
    /// color. Strikethrough is drawn by Text from the parsed intent. Text that isn't valid Markdown is shown as written.
    private func inline(_ text: String, size: CGFloat, weight: Font.Weight = .regular, color: Color, tint: Color?) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        var attributed = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        attributed[AttributeScopes.SwiftUIAttributes.FontAttribute.self] = theme.font(size, weight: weight)
        attributed[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = color

        var runs: [(range: Range<AttributedString.Index>, intent: InlinePresentationIntent, link: Bool)] = []
        for run in attributed.runs {
            runs.append((run.range, run.inlinePresentationIntent ?? [], run.link != nil))
        }
        for run in runs {
            let intent = run.intent
            if intent.contains(.code) {
                attributed[run.range][AttributeScopes.SwiftUIAttributes.FontAttribute.self] = theme.font(size - 1, mono: true)
                attributed[run.range][AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = tint ?? Color(theme.text)
                attributed[run.range][AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self] = Color(theme.well)
                continue
            }
            if intent.contains(.stronglyEmphasized) || intent.contains(.emphasized) {
                var font = theme.font(size, weight: intent.contains(.stronglyEmphasized) ? .semibold : weight)
                if intent.contains(.emphasized) { font = font.italic() }
                attributed[run.range][AttributeScopes.SwiftUIAttributes.FontAttribute.self] = font
            }
            if intent.contains(.stronglyEmphasized) {
                attributed[run.range][AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = tint ?? Color(theme.text)
            }
            if run.link {
                attributed[run.range][AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Color(theme.info)
            }
        }
        return attributed
    }
}

// MARK: Layout

private struct PieceSpacing: LayoutValueKey {
    static let defaultValue: CGFloat = 0
}

private struct KeepWithNext: LayoutValueKey {
    static let defaultValue = false
}

/// Places pieces in columns with `MarkdownFlow`: whole pieces only, two columns balanced.
private struct MarkdownFlowLayout: Layout {
    var columns: Int
    var gap: CGFloat = 20

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = max((bounds.width - gap * CGFloat(columns - 1)) / CGFloat(columns), 0)
        let pieces = subviews.map { subview in
            MarkdownFlow.Piece(
                height: Double(subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height),
                spacing: Double(subview[PieceSpacing.self]),
                keepWithNext: subview[KeepWithNext.self]
            )
        }
        let slots = MarkdownFlow.place(pieces, columns: columns, height: Double(bounds.height))
        for (subview, slot) in zip(subviews, slots) {
            guard let slot else {
                subview.place(at: CGPoint(x: -10_000, y: -10_000), proposal: .zero)
                continue
            }
            subview.place(
                at: CGPoint(x: bounds.minX + CGFloat(slot.column) * (width + gap), y: bounds.minY + CGFloat(slot.y)),
                proposal: ProposedViewSize(width: width, height: CGFloat(slot.height))
            )
        }
    }
}
