import SwiftUI
import TjuvkikCore

/// Who said what, and when. s shows the newest message large, m the latest items that fit, l the
/// items grouped by day. Times are relative and redrawn every minute.
struct FeedView: View {
    let content: FeedContent
    let size: TileSize
    let theme: Theme

    var body: some View {
        TimelineView(.everyMinute) { context in
            layout(now: context.date, calendar: .current)
        }
    }

    @ViewBuilder private func layout(now: Date, calendar: Calendar) -> some View {
        switch TileLayout(size) {
        case .s:
            if let item = content.newest {
                big(item, more: content.moreUnread, when: item.when(now: now, calendar: calendar))
            } else {
                empty
            }
        case .m:
            FittingStack(spacing: 0) {
                ForEach(Array(content.newestFirst.enumerated()), id: \.offset) { index, item in
                    FeedRow(item: item, when: item.when(now: now, calendar: calendar), isFirst: index == 0, theme: theme)
                }
            }
        case .l:
            if content.items.isEmpty {
                empty
            } else {
                FittingStack(spacing: 0) {
                    ForEach(Array(entries(now: now, calendar: calendar).enumerated()), id: \.offset) { _, entry in
                        // A day's heading and its first item are one child, so a heading is never
                        // left at the bottom without an item under it.
                        VStack(alignment: .leading, spacing: 0) {
                            if let title = entry.title {
                                Text(title.uppercased())
                                    .font(theme.font(10, weight: .semibold))
                                    .tracking(theme.z(0.6))
                                    .foregroundStyle(Color(theme.tertiaryText))
                                    .lineLimit(1)
                                    .padding(.top, theme.z(4))
                                    .padding(.bottom, theme.z(6))
                            }
                            FeedRow(item: entry.item, when: entry.item.when(now: now, calendar: calendar),
                                    isFirst: entry.startsDay, theme: theme)
                        }
                    }
                }
            }
        }
    }

    private var empty: some View {
        Text("Nothing yet").font(theme.font(11.5)).foregroundStyle(Color(theme.tertiaryText))
    }

    /// The newest message, large, at the bottom of the tile, with who and when under it.
    private func big(_ item: FeedContent.Item, more: Int, when: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            Text(FeedMessage.text(item.text, theme: theme, boldSize: 14))
                .font(theme.font(14))
                .lineSpacing(theme.z(3))
                .foregroundStyle(Color(theme.text))
                .lineLimit(4)
            HStack(spacing: theme.z(7)) {
                FeedAvatarView(item: item, diameter: 20, theme: theme)
                Text([item.author, when].compactMap { $0 }.joined(separator: " · "))
                    .font(theme.font(11.5).monospacedDigit())
                    .foregroundStyle(Color(theme.secondaryText))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if more > 0 {
                    Text("+\(more)")
                        .font(theme.font(11.5).monospacedDigit())
                        .foregroundStyle(Color(theme.info))
                        .fixedSize()
                }
            }
            .padding(.top, theme.z(10))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private struct Entry {
        var title: String?
        var item: FeedContent.Item
        var startsDay: Bool
    }

    private func entries(now: Date, calendar: Calendar) -> [Entry] {
        content.days(now: now, calendar: calendar).flatMap { day in
            day.items.enumerated().map { index, item in
                Entry(title: index == 0 ? day.title : nil, item: item, startsDay: index == 0)
            }
        }
    }
}

/// One message: avatar, author and where, the time, and two lines of text. Items after the first
/// of a run have a line above them.
private struct FeedRow: View {
    let item: FeedContent.Item
    let when: String?
    let isFirst: Bool
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isFirst {
                Rectangle().fill(Color(theme.line)).frame(height: theme.z(1))
            }
            HStack(alignment: .top, spacing: theme.z(9)) {
                FeedAvatarView(item: item, diameter: 26, theme: theme)
                VStack(alignment: .leading, spacing: theme.z(1)) {
                    HStack(alignment: .center, spacing: theme.z(6)) {
                        if item.unread {
                            Circle().fill(Color(theme.info)).frame(width: theme.z(6), height: theme.z(6))
                        }
                        who
                            .font(theme.font(12))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: theme.z(4))
                        if let when {
                            Text(when)
                                .font(theme.font(10.5).monospacedDigit())
                                .foregroundStyle(Color(theme.tertiaryText))
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    Text(FeedMessage.text(item.text, theme: theme, boldSize: 12))
                        .font(theme.font(12))
                        .lineSpacing(theme.z(2))
                        .foregroundStyle(Color(theme.secondaryText))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, isFirst ? 0 : theme.z(7))
            .padding(.bottom, theme.z(7))
        }
        .clickable(RowAction(url: item.url, title: item.text, actions: item.actions), theme: theme)
    }

    /// "Sara Lind #dsp-spark": the author bold, where after it, dimmer.
    private var who: Text {
        let author = Text(item.author ?? "").fontWeight(.semibold).foregroundStyle(Color(theme.text))
        guard let place = item.place, !place.isEmpty else { return author }
        return author + Text(item.author == nil ? place : " \(place)").foregroundStyle(Color(theme.secondaryText))
    }
}

/// The author's picture, the item's icon in a square, or initials on a color from the name.
private struct FeedAvatarView: View {
    let item: FeedContent.Item
    let diameter: CGFloat
    let theme: Theme

    var body: some View {
        if let icon = item.icon, !icon.isEmpty {
            Text(icon)
                .font(theme.font(diameter * 0.5))
                .frame(width: theme.z(diameter), height: theme.z(diameter))
                .background(Color(theme.well), in: RoundedRectangle(cornerRadius: theme.z(diameter * 0.27), style: .continuous))
        } else {
            let name = item.author ?? item.place ?? ""
            ZStack {
                Circle().fill(theme.color(for: FeedAuthor.tone(name), default: theme.accent))
                Text(FeedAuthor.initials(name))
                    .font(theme.font(diameter * 0.4, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let avatar = item.avatar, let url = URL(string: avatar) {
                    // The initials show while the picture loads, and if it can't.
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.clear
                        }
                    }
                }
            }
            .frame(width: theme.z(diameter), height: theme.z(diameter))
            .clipShape(Circle())
        }
    }
}

/// A message's text, where `**bold**` and other inline Markdown read brighter than the rest.
private enum FeedMessage {
    static func text(_ text: String, theme: Theme, boldSize: CGFloat) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard var attributed = try? AttributedString(markdown: text, options: options) else {
            return AttributedString(text)
        }
        for run in attributed.runs where run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
            attributed[run.range][AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Color(theme.text)
            attributed[run.range][AttributeScopes.SwiftUIAttributes.FontAttribute.self] = theme.font(boldSize, weight: .medium)
        }
        return attributed
    }
}
