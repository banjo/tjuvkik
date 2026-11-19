import SwiftUI
import TjuvkikCore

/// A few numbers, each against its last period. s shows the first big, m three in a row, l six in
/// a 2×3 grid.
struct StatsView: View {
    let content: StatsContent
    let size: TileSize
    let theme: Theme

    var body: some View {
        switch TileLayout(size) {
        case .s:
            if let stat = content.stats.first { single(stat) }
        case .m:
            HStack(spacing: theme.z(8)) {
                ForEach(Array(content.stats.prefix(3).enumerated()), id: \.offset) { _, stat in cell(stat) }
            }
        case .l:
            let stats = Array(content.stats.prefix(6))
            let rows = stride(from: 0, to: stats.count, by: 2).map { Array(stats[$0..<min($0 + 2, stats.count)]) }
            VStack(spacing: theme.z(8)) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: theme.z(8)) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, stat in cell(stat) }
                        // A lone last stat keeps the width of the others.
                        if row.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                    }
                }
            }
        }
    }

    /// The first stat, big, at the bottom of the tile.
    private func single(_ stat: StatsContent.Stat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            if let label = stat.label {
                Text(label).font(theme.font(11.5)).foregroundStyle(Color(theme.secondaryText)).lineLimit(1)
            }
            ValueText(value: stat.value, unit: stat.unit, size: 34, unitSize: 15, theme: theme)
                .padding(.top, theme.z(6))
            DeltaLine(delta: stat.delta, tone: stat.tone, vs: stat.vs, vsSize: 11, theme: theme)
                .padding(.top, theme.z(6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private func cell(_ stat: StatsContent.Stat) -> some View {
        VStack(alignment: .leading, spacing: theme.z(4)) {
            Text(stat.label ?? " ")
                .font(theme.font(11.5))
                .foregroundStyle(Color(theme.secondaryText))
                .lineLimit(1)
            Spacer(minLength: 0)
            ValueText(value: stat.value, unit: stat.unit, size: 22, unitSize: 12, theme: theme)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            DeltaLine(delta: stat.delta, tone: stat.tone, vs: stat.vs, theme: theme)
        }
        .padding(.vertical, theme.z(9))
        .padding(.horizontal, theme.z(11))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .well(theme)
    }
}
