import SwiftUI
import TjuvkikCore

/// A script panel: hero number, progress bar, then as many rows as fit.
struct RowsView: View {
    let content: RowsContent
    let theme: Theme

    var body: some View {
        FittingStack(spacing: 2) {
            if let hero = content.hero {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(hero.value)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.color(for: hero.tone, default: theme.text))
                    if let label = hero.label {
                        Text(label).font(.system(size: 12)).foregroundStyle(Color(theme.secondaryText)).lineLimit(1)
                    }
                }
                .padding(.bottom, 4)
            }
            if let progress = content.progress {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(theme.well))
                        Capsule().fill(Color(theme.accent)).frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 4)
                .padding(.bottom, 8)
            }
            ForEach(Array(content.rows.enumerated()), id: \.offset) { _, row in
                RowView(row: row, theme: theme)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct RowView: View {
    let row: RowsContent.Row
    let theme: Theme

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let icon = row.icon {
                Text(icon).font(.system(size: 13)).frame(width: 18)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color(row.tone == .muted ? theme.secondaryText : theme.text))
                    .lineLimit(1)
                if let subtitle = row.subtitle {
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(Color(theme.tertiaryText)).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if let trailing = row.trailing {
                Text(trailing)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(theme.color(for: row.tone, default: theme.tertiaryText))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A cli panel: the command's output, cut to what fits.
struct TextOutputView: View {
    let text: String
    let theme: Theme

    var body: some View {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        FittingStack {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line.isEmpty ? " " : line)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Color(theme.secondaryText))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(theme.well), in: RoundedRectangle(cornerRadius: max(theme.radius - 6, 4), style: .continuous))
    }
}
