import AppKit
import SwiftUI
import TjuvkikCore

/// The same fields for every row. s shows up to two columns, m up to four, l every column that
/// fits; columns past the tile's width drop from the right, and `priority` keeps one longer.
struct TableView: View {
    let content: TableContent
    let size: TileSize
    let theme: Theme

    private static let spacing: CGFloat = 12
    private static let cellSize: CGFloat = 11.5
    private static let monoSize: CGFloat = 11
    private static let headerSize: CGFloat = 10
    /// The most a column asks for when deciding what fits; wider text is cut instead.
    private static let widest: CGFloat = 120

    var body: some View {
        GeometryReader { proxy in
            let shown = visible(in: proxy.size.width)
            let widths = TableLayout.widths(
                shares: shown.map { content.columns[$0].width },
                available: max(proxy.size.width - Self.spacing * CGFloat(max(shown.count - 1, 0)), 0)
            ).map { CGFloat($0) }
            VStack(alignment: .leading, spacing: 0) {
                header(shown, widths)
                FittingStack(spacing: 0) {
                    ForEach(Array(content.rows.enumerated()), id: \.offset) { _, row in
                        line(row, shown, widths)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }

    /// The columns that fit in `width`, in their order.
    private func visible(in width: CGFloat) -> [Int] {
        let limit: Int = switch TileLayout(size) {
        case .s: 2
        case .m: 4
        case .l: Int.max
        }
        let count = TableLayout.fittingCount(
            widths: content.columns.indices.map { Double(needed($0)) },
            priorities: content.columns.map(\.priority),
            available: Double(width),
            spacing: Double(Self.spacing),
            limit: limit
        )
        return TableLayout.visibleColumns(priorities: content.columns.map(\.priority), fitting: count)
    }

    private func header(_ shown: [Int], _ widths: [CGFloat]) -> some View {
        HStack(spacing: Self.spacing) {
            ForEach(Array(shown.enumerated()), id: \.offset) { position, index in
                let column = content.columns[index]
                Text(column.title.uppercased())
                    .font(.system(size: Self.headerSize, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Color(theme.tertiaryText))
                    .lineLimit(1)
                    .frame(width: widths[position], alignment: alignment(column.align))
            }
        }
        .padding(.bottom, 6)
    }

    private func line(_ row: TableContent.Row, _ shown: [Int], _ widths: [CGFloat]) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color(theme.line)).frame(height: 1)
            HStack(spacing: Self.spacing) {
                ForEach(Array(shown.enumerated()), id: \.offset) { position, index in
                    cell(row.cell(index), content.columns[index])
                        .frame(width: widths[position], alignment: alignment(content.columns[index].align))
                }
            }
            .padding(.vertical, 5)
            .background {
                if let tone = row.highlight {
                    theme.color(for: tone, default: theme.text).opacity(0.08)
                }
            }
        }
    }

    private func cell(_ cell: TableContent.Cell, _ column: TableContent.Column) -> some View {
        let color = cell.dim && cell.tone == nil
            ? Color(theme.secondaryText)
            : theme.color(for: cell.tone, default: theme.text)
        return HStack(spacing: 6) {
            if cell.dot {
                Circle().fill(color).frame(width: 6, height: 6)
            }
            Text(cell.text)
                .font(column.mono
                    ? .system(size: Self.monoSize, design: .monospaced)
                    : .system(size: Self.cellSize).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func alignment(_ align: TableContent.Column.Align) -> Alignment {
        switch align {
        case .left: .leading
        case .right: .trailing
        case .center: .center
        }
    }

    /// The narrowest a column can be and still read: its header and widest cell, up to `widest`.
    private func needed(_ index: Int) -> CGFloat {
        let column = content.columns[index]
        let cellFont = column.mono
            ? NSFont.monospacedSystemFont(ofSize: Self.monoSize, weight: .regular)
            : NSFont.monospacedDigitSystemFont(ofSize: Self.cellSize, weight: .regular)
        let headerFont = NSFont.systemFont(ofSize: Self.headerSize, weight: .semibold)
        let title = column.title.uppercased()
        var widest = measure(title, headerFont) + 0.6 * CGFloat(title.count)
        // The first rows are enough for an estimate, and keep this cheap for long tables.
        for row in content.rows.prefix(30) {
            let cell = row.cell(index)
            widest = max(widest, measure(cell.text, cellFont) + (cell.dot ? 12 : 0))
        }
        return min(ceil(widest), Self.widest)
    }

    private func measure(_ text: String, _ font: NSFont) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        return (text as NSString).size(withAttributes: [.font: font]).width
    }
}
