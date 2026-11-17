import SwiftUI
import TjuvkikCore

/// Many things at once, a colored cell each. s shows the worst count and a dot per row, m a chip
/// per row, l a row each with its history as cells. With `levels`, every size is a heatmap.
struct GridView: View {
    let content: GridContent
    let size: TileSize
    let theme: Theme

    var body: some View {
        if content.levels != nil {
            heatmap(footer: TileLayout(size) != .s)
        } else {
            switch TileLayout(size) {
            case .s: dots
            case .m: chips
            case .l: history
            }
        }
    }

    // MARK: - s

    /// The worst count, what the rest are, then a dot per row at the bottom.
    private var dots: some View {
        let headline = content.headline
        return VStack(alignment: .leading, spacing: 0) {
            Text(headline.value)
                .font(theme.font(26, weight: .semibold).monospacedDigit())
                .tracking(-0.52)
                .foregroundStyle(theme.color(for: headline.tone, default: theme.text))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let label = headline.label {
                Text(label)
                    .font(theme.font(11.5))
                    .foregroundStyle(Color(theme.secondaryText))
                    .lineLimit(1)
                    .padding(.top, 4)
            }
            GeometryReader { geo in
                let side: CGFloat = 13, gap: CGFloat = 4
                let perLine = max(1, Int((geo.size.width + gap) / (side + gap)))
                let lines = max(0, Int((geo.size.height + gap) / (side + gap)))
                let shown = Array(content.rows.prefix(perLine * lines))
                let rows = stride(from: 0, to: shown.count, by: perLine).map { Array(shown[$0..<min($0 + perLine, shown.count)]) }
                VStack(alignment: .leading, spacing: gap) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, line in
                        HStack(spacing: gap) {
                            ForEach(Array(line.enumerated()), id: \.offset) { _, row in
                                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                    .fill(theme.color(for: row.status, default: theme.line))
                                    .opacity(row.status == .success ? 0.45 : 0.85)
                                    .frame(width: side, height: side)
                            }
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - m

    /// A chip per row, three to a line, as many lines as fit.
    private var chips: some View {
        let lines = stride(from: 0, to: content.rows.count, by: 3).map { Array(content.rows[$0..<min($0 + 3, content.rows.count)]) }
        return FittingStack(spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(spacing: 6) {
                    ForEach(Array(line.enumerated()), id: \.offset) { _, row in chip(row) }
                    ForEach(line.count..<3, id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func chip(_ row: GridContent.Row) -> some View {
        let tone = theme.color(for: row.status, default: theme.tertiaryText)
        let loud = row.status == .error || row.status == .warning
        return HStack(spacing: 4) {
            ZStack {
                Circle().fill(tone.opacity(0.18)).frame(width: 13, height: 13)
                Circle().fill(tone).frame(width: 7, height: 7)
            }
            Text(row.label)
                .font(theme.font(11.5))
                .foregroundStyle(Color(theme.text))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let value = row.value {
                Text(value)
                    .font(theme.font(10.5).monospacedDigit())
                    .foregroundStyle(loud ? tone : Color(theme.tertiaryText))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, 5)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity)
        .well(theme, radius: 8)
    }

    // MARK: - l

    private var hasValues: Bool { content.rows.contains { $0.value != nil } }
    private let labelWidth: CGFloat = 92
    private let valueWidth: CGFloat = 44
    private let columnGap: CGFloat = 10

    /// A row per item with its cells, spread over the height; the axis and legend below.
    private var history: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let fit = max(0, Int((geo.size.height + 7) / (18 + 7)))
                VStack(spacing: 0) {
                    ForEach(Array(content.rows.prefix(fit).enumerated()), id: \.offset) { _, row in
                        Spacer(minLength: 0)
                        historyRow(row)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            if let axis = content.axis, !axis.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(axis.enumerated()), id: \.offset) { index, text in
                        if index > 0 { Spacer(minLength: 4) }
                        Text(text).lineLimit(1)
                    }
                }
                .font(theme.font(10).monospacedDigit())
                .foregroundStyle(Color(theme.tertiaryText))
                .padding(.leading, labelWidth + columnGap)
                .padding(.trailing, hasValues ? valueWidth + columnGap : 0)
                .padding(.top, 3)
            }
            if !content.legend.isEmpty || content.footer != nil {
                HStack(spacing: 12) {
                    ForEach(Array(content.legend.enumerated()), id: \.offset) { _, entry in
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(theme.color(for: entry.tone, default: theme.line))
                                .opacity(entry.tone == .success ? 0.55 : 1)
                                .frame(width: 8, height: 8)
                            Text(entry.text).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    if let footer = content.footer {
                        Text(footer).lineLimit(1).truncationMode(.tail)
                    }
                }
                .font(theme.font(10.5))
                .foregroundStyle(Color(theme.tertiaryText))
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func historyRow(_ row: GridContent.Row) -> some View {
        HStack(spacing: columnGap) {
            Text(row.label)
                .font(theme.font(12))
                .foregroundStyle(Color(theme.text))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: labelWidth, alignment: .leading)
            HStack(spacing: 2) {
                ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(fill(cell))
                        .opacity(opacity(cell))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18)
            if hasValues {
                Text(row.value ?? "")
                    .font(theme.font(11).monospacedDigit())
                    .foregroundStyle(row.tone.map { theme.color(for: $0, default: theme.secondaryText) } ?? Color(theme.secondaryText))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: valueWidth, alignment: .trailing)
            }
        }
        .frame(height: 18)
    }

    private func fill(_ cell: GridContent.Cell) -> Color {
        switch cell {
        case .tone(let tone): theme.color(for: tone, default: theme.line)
        case .level: heat
        }
    }

    private func opacity(_ cell: GridContent.Cell) -> Double {
        switch cell {
        case .tone(let tone): tone == .success ? 0.55 : 1
        case .level(let level): GridContent.opacity(level: level)
        }
    }

    // MARK: - Heatmap

    private var heat: Color { theme.color(for: content.tone, default: theme.accent) }

    /// Columns of levels, the newest that fit at least 8pt wide; the footer and a key below.
    private func heatmap(footer: Bool) -> some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let gap: CGFloat = 3, minCell: CGFloat = 8
                let height = max(content.levelHeight, 1)
                let columns = content.heatmap(limit: max(1, Int((geo.size.width + gap) / (minCell + gap))))
                HStack(spacing: gap) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                        VStack(spacing: gap) {
                            ForEach(0..<height, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                    .fill(heat)
                                    .opacity(index < column.count ? GridContent.opacity(level: column[index]) : 0)
                            }
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            if footer {
                HStack(spacing: 12) {
                    if let text = content.footer {
                        Text(text).lineLimit(1).truncationMode(.tail)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 3) {
                        Text("less").padding(.trailing, 2)
                        ForEach(0..<5, id: \.self) { level in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(heat)
                                .opacity(GridContent.opacity(level: level))
                                .frame(width: 8, height: 8)
                        }
                        Text("more").padding(.leading, 2)
                    }
                    .fixedSize()
                }
                .font(theme.font(11).monospacedDigit())
                .foregroundStyle(Color(theme.tertiaryText))
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
