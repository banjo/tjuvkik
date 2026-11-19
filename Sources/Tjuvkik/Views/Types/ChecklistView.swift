import SwiftUI
import TjuvkikCore

/// Steps and how far along they are. s shows the count, a bar and the next step, m the items in
/// one or two columns, l sections and notes with done steps folded.
struct ChecklistView: View {
    let content: ChecklistContent
    let size: TileSize
    let theme: Theme
    @Environment(\.tileScroll) private var scroll

    /// A one-line step: 4 above and below a 12.5pt line at 1.35.
    private static let rowHeight: CGFloat = 25

    var body: some View {
        switch TileLayout(size) {
        case .s: small
        case .m: medium
        case .l: large
        }
    }

    // MARK: Sizes

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            header
            bar.padding(.bottom, theme.z(8))
            if let next = content.next {
                label("Next")
                Text(next.title)
                    .font(theme.font(13, weight: .medium))
                    .foregroundStyle(Color(theme.text))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, theme.z(2))
            } else if let blocked = content.tasks.first(where: { $0.state == .blocked }) {
                label("Blocked")
                Text(blocked.title)
                    .font(theme.font(13, weight: .medium))
                    .foregroundStyle(Color(theme.error))
                    .lineLimit(1)
                    .padding(.top, theme.z(2))
            } else if content.isComplete {
                Text("All done")
                    .font(theme.font(13, weight: .medium))
                    .foregroundStyle(Color(theme.success))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private var medium: some View {
        GeometryReader { geometry in
            let tasks = content.tasks
            let fit = Int(geometry.size.height / theme.z(Self.rowHeight))
            let columns = ChecklistContent.columns(for: tasks.count, rowsThatFit: fit)
            let rows = stride(from: 0, to: tasks.count, by: columns).map { Array(tasks[$0..<min($0 + columns, tasks.count)]) }
            FittingStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: theme.z(18)) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, task in
                            item(task).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        // A lone last step keeps the width of the others.
                        if row.count < columns { Color.clear.frame(maxWidth: .infinity, maxHeight: 0) }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            bar.padding(.bottom, theme.z(8))
            FittingStack(spacing: 0, skip: scroll) {
                ForEach(Array(content.visibleItems.enumerated()), id: \.offset) { index, entry in
                    switch entry {
                    case .section(let title):
                        section(title, first: index == scroll).scrollItem(index)
                    case .task(let task):
                        item(task).scrollItem(index)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            if let folded = content.foldedLine {
                Text(folded)
                    .font(theme.font(11))
                    .foregroundStyle(Color(theme.tertiaryText))
                    .lineLimit(1)
                    .padding(.top, theme.z(6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Parts

    /// "2/8  steps · release Thu 14:00"
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.z(8)) {
            Text(content.count)
                .font(theme.font(20, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color(theme.text))
                .fixedSize()
            if let caption = content.caption {
                Text(caption)
                    .font(theme.font(11.5))
                    .foregroundStyle(Color(theme.secondaryText))
                    .truncationMode(.tail)
            }
        }
        .lineLimit(1)
        .padding(.bottom, theme.z(6))
    }

    /// Done in the success color, then in progress in the accent color.
    private var bar: some View {
        GeometryReader { geometry in
            let done = geometry.size.width * content.progress
            let doing = geometry.size.width * content.doingProgress
            HStack(spacing: theme.z(2)) {
                if done > 0 { Rectangle().fill(Color(theme.success)).frame(width: done) }
                if doing > 0 { Rectangle().fill(Color(theme.accent)).frame(width: max(doing - (done > 0 ? theme.z(2) : 0), 0)) }
                Spacer(minLength: 0)
            }
        }
        .frame(height: theme.z(4))
        .background(Color(theme.well))
        .clipShape(Capsule())
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(theme.font(10, weight: .semibold))
            .tracking(theme.z(0.6))
            .foregroundStyle(Color(theme.tertiaryText))
            .lineLimit(1)
            .padding(.top, theme.z(8))
    }

    private func section(_ title: String, first: Bool) -> some View {
        Text(title.uppercased())
            .font(theme.font(10, weight: .semibold))
            .tracking(theme.z(0.6))
            .foregroundStyle(Color(theme.tertiaryText))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, theme.z(first ? 2 : 8))
            .padding(.bottom, theme.z(2))
    }

    private func item(_ task: ChecklistContent.Task) -> some View {
        let finished = task.state == .done || task.state == .skipped
        return HStack(alignment: .top, spacing: theme.z(9)) {
            box(task.state).padding(.top, theme.z(1))
            VStack(alignment: .leading, spacing: theme.z(1)) {
                Text(task.title)
                    .font(theme.font(12.5))
                    .foregroundStyle(Color(finished ? theme.tertiaryText : theme.text))
                    .strikethrough(finished, color: ink.opacity(0.25))
                    .lineSpacing(theme.z(2))
                    .lineLimit(2)
                if let note = task.note {
                    Text(note)
                        .font(theme.font(11))
                        .foregroundStyle(Color(task.state == .blocked ? theme.error : theme.secondaryText))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let who = task.who {
                Text(who)
                    .font(theme.font(10.5))
                    .foregroundStyle(Color(theme.tertiaryText))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.top, theme.z(1.5))
            }
        }
        .padding(.vertical, theme.z(4))
    }

    /// The 15pt box: empty for todo, ticked for done, a square for doing, "!" for blocked, a
    /// dash for skipped.
    private func box(_ state: ChecklistContent.State) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.z(4.5), style: .continuous)
        return ZStack {
            switch state {
            case .done:
                shape.fill(Color(theme.success))
                Text("✓").font(theme.font(10, weight: .bold)).foregroundStyle(Color.black.opacity(0.8))
            case .doing:
                shape.strokeBorder(Color(theme.accent), lineWidth: theme.z(1.5))
                RoundedRectangle(cornerRadius: theme.z(2), style: .continuous).fill(Color(theme.accent)).frame(width: theme.z(7), height: theme.z(7))
            case .blocked:
                shape.strokeBorder(Color(theme.error), lineWidth: theme.z(1.5))
                Text("!").font(theme.font(10, weight: .bold)).foregroundStyle(Color(theme.error))
            case .skipped:
                shape.strokeBorder(ink.opacity(0.18), lineWidth: theme.z(1.5))
                Text("–").font(theme.font(10, weight: .bold)).foregroundStyle(Color(theme.tertiaryText))
            case .todo:
                shape.strokeBorder(ink.opacity(0.28), lineWidth: theme.z(1.5))
            }
        }
        .frame(width: theme.z(15), height: theme.z(15))
    }

    private var ink: Color { theme.appearance == .dark ? .white : .black }
}
