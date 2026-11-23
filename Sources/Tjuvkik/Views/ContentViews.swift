import SwiftUI
import TjuvkikCore

/// A script panel: hero number, summary, progress bar, then as many rows as fit.
struct RowsView: View {
    let content: RowsContent
    let theme: Theme
    @Environment(\.tileScroll) private var scroll

    var body: some View {
        FittingStack(spacing: theme.z(2), skip: scroll) {
            if let hero = content.hero {
                HStack(alignment: .firstTextBaseline, spacing: theme.z(8)) {
                    Text(hero.value)
                        .font(theme.font(30, weight: .semibold, rounded: true))
                        .foregroundStyle(theme.color(for: hero.tone, default: theme.text))
                    if let label = hero.label {
                        Text(label).font(theme.font(12)).foregroundStyle(Color(theme.secondaryText)).lineLimit(1)
                    }
                }
                .padding(.bottom, theme.z(4))
            }
            if let summary = content.summary, !summary.isEmpty {
                SummaryView(chips: summary, theme: theme).padding(.bottom, theme.z(6))
            }
            if let progress = content.progress {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(theme.well))
                        Capsule().fill(Color(theme.accent)).frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: theme.z(4))
                .padding(.bottom, theme.z(8))
            }
            ForEach(Array(content.rows.enumerated()), id: \.offset) { index, row in
                // The first row in view gets its group's heading too, so a scrolled list says
                // what it's in.
                if let group = row.group, index == 0 || index == scroll || content.rows[index - 1].group != group {
                    Text(group.uppercased())
                        .font(theme.font(9.5, weight: .semibold))
                        .tracking(theme.z(0.6))
                        .foregroundStyle(Color(theme.tertiaryText))
                        .lineLimit(1)
                        .padding(.top, index == 0 || index == scroll ? 0 : theme.z(6))
                        .scrollItem(index)
                }
                RowView(row: row, theme: theme).scrollItem(index)
                if let note = row.note {
                    NoteView(text: note, tone: row.tone, theme: theme).scrollItem(index)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SummaryView: View {
    let chips: [RowsContent.Chip]
    let theme: Theme

    var body: some View {
        HStack(spacing: theme.z(12)) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                HStack(spacing: theme.z(4)) {
                    if let icon = Icon(chip.icon) {
                        IconView(icon: icon, size: 11.5, color: theme.color(for: chip.tone, default: theme.secondaryText), theme: theme)
                    }
                    if let value = chip.value {
                        Text(value)
                            .font(theme.font(12, weight: .semibold).monospacedDigit())
                            .foregroundStyle(theme.color(for: chip.tone, default: theme.text))
                    }
                    if let label = chip.label {
                        Text(label).font(theme.font(11.5)).foregroundStyle(Color(theme.secondaryText))
                    }
                }
                .lineLimit(1)
            }
        }
    }
}

/// What a row needs from you, under it: "Bash: rm -rf node_modules".
private struct NoteView: View {
    let text: String
    let tone: Tone?
    let theme: Theme

    var body: some View {
        let color = theme.color(for: tone, default: theme.secondaryText)
        Text(text)
            .font(theme.font(11, mono: true))
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, theme.z(8))
            .padding(.vertical, theme.z(4))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.background(for: tone, color: color, opacity: 0.1), in: RoundedRectangle(cornerRadius: theme.z(6), style: .continuous))
            .padding(.leading, theme.z(26))
            .padding(.bottom, theme.z(2))
    }
}

private struct RowView: View {
    let row: RowsContent.Row
    let theme: Theme

    var body: some View {
        HStack(alignment: .center, spacing: theme.z(8)) {
            if let icon = Icon(row.icon) {
                IconView(icon: icon, size: 13, color: theme.color(for: row.tone, default: theme.secondaryText), theme: theme)
                    .frame(width: theme.z(18))
            }
            VStack(alignment: .leading, spacing: theme.z(1)) {
                title.reportsTruncation().lineLimit(1)
                if let subtitle {
                    subtitle.reportsTruncation().lineLimit(1)
                }
            }
            .peekAnchor()
            Spacer(minLength: theme.z(4))
            if let trailing = row.trailing {
                Text(trailing)
                    .font(theme.font(11).monospacedDigit())
                    .foregroundStyle(theme.color(for: row.tone, default: theme.tertiaryText))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, theme.z(4))
        .clickable(RowAction(url: row.url, command: row.command, title: row.title, actions: row.actions), theme: theme, tone: row.tone)
        .peek([PeekLine(text: title)] + (subtitle.map { [PeekLine(text: $0)] } ?? []), spacing: theme.z(1))
    }

    private var title: Text {
        Text(row.title)
            .font(theme.font(12.5, weight: .medium))
            .foregroundStyle(Color(row.tone == .muted ? theme.secondaryText : theme.text))
    }

    private var subtitle: Text? {
        row.subtitle.map { Text($0).font(theme.font(11)).foregroundStyle(Color(theme.tertiaryText)) }
    }
}

/// A cli panel: the command's output, cut to what fits. A tail shows the last lines.
struct TextOutputView: View {
    let text: String
    var tail = false
    let theme: Theme

    var body: some View {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        FittingStack(fromBottom: tail) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line.isEmpty ? " " : line)
                    .font(theme.font(10.5, mono: true))
                    .foregroundStyle(Color(theme.secondaryText))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(theme.z(8))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(theme.well), in: RoundedRectangle(cornerRadius: max(theme.radius - theme.z(6), theme.z(4)), style: .continuous))
    }
}
