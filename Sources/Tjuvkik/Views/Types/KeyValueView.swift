import SwiftUI
import TjuvkikCore

/// Exact facts, grouped. s shows label above value, m two columns of pairs, l one list with
/// section headings. Values are monospaced and cut in the middle, so the ends of IDs and paths
/// stay visible. Only whole pairs are shown.
struct KeyValueView: View {
    let content: KeyValueContent
    let size: TileSize
    let theme: Theme

    var body: some View {
        switch TileLayout(size) {
        case .s:
            stacked(content.pairs)
        case .m:
            let columns = content.columns
            HStack(alignment: .top, spacing: 22) {
                list(columns.left)
                list(columns.right)
            }
        case .l:
            list(content.sections)
        }
    }

    /// Label above value, a line under each.
    private func stacked(_ pairs: [KeyValueContent.Pair]) -> some View {
        FittingStack(spacing: 0) {
            ForEach(Array(pairs.enumerated()), id: \.offset) { index, pair in
                VStack(alignment: .leading, spacing: 0) {
                    Text(pair.key)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(theme.secondaryText))
                        .lineLimit(1)
                    value(pair, size: 13)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, index == 0 ? 0 : 6)
                .padding(.bottom, 6)
                .overlay(alignment: .bottom) { Rectangle().fill(Color(theme.line)).frame(height: 1) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Key left, value right, a line between pairs, headings above their sections.
    private func list(_ sections: [KeyValueContent.Section]) -> some View {
        FittingStack(spacing: 0) {
            ForEach(Array(Self.lines(sections).enumerated()), id: \.offset) { _, line in
                VStack(alignment: .leading, spacing: 0) {
                    if let heading = line.heading {
                        Text(heading.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(Color(theme.tertiaryText))
                            .lineLimit(1)
                            .padding(.top, line.isFirst ? 0 : 10)
                            .padding(.bottom, 2)
                    }
                    row(line.pair, divider: !line.isFirst)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ pair: KeyValueContent.Pair, divider: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(pair.key)
                .font(.system(size: 12))
                .foregroundStyle(Color(theme.secondaryText))
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: 14)
            value(pair, size: 11.5)
        }
        .padding(.vertical, 5)
        .overlay(alignment: .top) {
            if divider { Rectangle().fill(Color(theme.line)).frame(height: 1) }
        }
    }

    /// Monospaced, in its tone, cut in the middle; on a tinted capsule for a pill.
    @ViewBuilder private func value(_ pair: KeyValueContent.Pair, size: CGFloat) -> some View {
        let color = theme.color(for: pair.tone, default: theme.text)
        let text = Text(pair.value)
            .font(.system(size: size, design: .monospaced))
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.middle)
        if pair.pill && pair.tone != nil {
            text
                .padding(.horizontal, 6)
                .background(color.opacity(0.16), in: Capsule())
        } else {
            text
        }
    }

    /// One pair per line, a heading kept with the first pair under it so it's never shown alone.
    private struct Line {
        var heading: String?
        var pair: KeyValueContent.Pair
        var isFirst: Bool
    }

    private static func lines(_ sections: [KeyValueContent.Section]) -> [Line] {
        var lines: [Line] = []
        for section in sections {
            for (index, pair) in section.pairs.enumerated() {
                lines.append(Line(heading: index == 0 ? section.title : nil, pair: pair, isFirst: lines.isEmpty))
            }
        }
        return lines
    }
}
