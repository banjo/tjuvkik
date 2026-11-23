import SwiftUI
import TjuvkikCore

/// Spotlight's preview of one row: its whole text, what the list leaves out, where Enter takes
/// it and what else it can do.
struct SpotlightDetail: View {
    let item: SpotlightItem
    let tile: Tile
    let state: PanelStore.State?
    let theme: Theme

    var body: some View {
        let radius = CGFloat(theme.radius)
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.z(14)) {
                    header
                    if let note = item.note, !note.isEmpty { noteView(note) }
                    if !item.details.isEmpty { details }
                    if let action = SpotlightController.action(item), !action.isEmpty { commands(action) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(theme.z(16))
            }
            .scrollIndicators(.automatic)
            Rectangle().fill(Color(theme.line)).frame(height: 1)
            footer
                .padding(.horizontal, theme.z(16))
                .frame(height: theme.z(32))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(theme.well).opacity(0.5), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color(theme.line), lineWidth: 1))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: theme.z(6)) {
            Text([tile.title, item.group].compactMap { $0 }.joined(separator: " · "))
                .font(theme.font(10.5, weight: .semibold))
                .foregroundStyle(Color(theme.tertiaryText))
                .textCase(.uppercase)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: theme.z(10)) {
                if let icon = Icon(item.icon) {
                    IconView(icon: icon, size: 16, color: theme.color(for: item.tone, default: theme.secondaryText), theme: theme)
                }
                Text(item.title)
                    .font(theme.font(16, weight: .semibold))
                    .foregroundStyle(Color(theme.text))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Spacer(minLength: theme.z(8))
                if let trailing = item.trailing, !trailing.isEmpty {
                    let color = theme.color(for: item.tone, default: theme.secondaryText)
                    Text(trailing)
                        .font(theme.font(11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .padding(.horizontal, theme.z(7))
                        .padding(.vertical, theme.z(2))
                        .background(theme.background(for: item.tone, color: item.tone == nil ? Color(theme.text) : color, opacity: 0.14), in: Capsule())
                        .fixedSize()
                }
            }
            if let subtitle = item.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(theme.font(12.5))
                    .foregroundStyle(Color(theme.secondaryText))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func noteView(_ note: String) -> some View {
        let color = theme.color(for: item.tone, default: theme.secondaryText)
        return Text(note)
            .font(theme.font(11.5, mono: true))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, theme.z(10))
            .padding(.vertical, theme.z(7))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.background(for: item.tone, color: color, opacity: 0.1), in: RoundedRectangle(cornerRadius: theme.z(7), style: .continuous))
    }

    private var details: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: theme.z(14), verticalSpacing: theme.z(6)) {
            ForEach(Array(item.details.enumerated()), id: \.offset) { _, detail in
                GridRow {
                    Text(detail.label)
                        .font(theme.font(11.5))
                        .foregroundStyle(Color(theme.tertiaryText))
                        .lineLimit(1)
                    Text(detail.value)
                        .font(theme.font(12.5))
                        .foregroundStyle(theme.color(for: detail.tone, default: theme.text))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// Where Enter goes, then the row's other commands with their keys.
    private func commands(_ action: RowAction) -> some View {
        let commands = GlanceCommand.all(for: action).filter { command in
            switch command.kind {
            case .click, .openURL, .action, .copy: true
            default: false
            }
        }
        return VStack(alignment: .leading, spacing: theme.z(6)) {
            if let target = action.hasCommand ? action.command : action.hasURL ? action.url : nil {
                Text(target)
                    .font(theme.font(11, mono: true))
                    .foregroundStyle(Color(theme.secondaryText))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .padding(.horizontal, theme.z(8))
                    .padding(.vertical, theme.z(5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(theme.well), in: RoundedRectangle(cornerRadius: theme.z(6), style: .continuous))
                    .textSelection(.enabled)
            }
            ForEach(Array(commands.enumerated()), id: \.offset) { _, command in
                HStack(spacing: theme.z(8)) {
                    Text(command.title).font(theme.font(12.5)).foregroundStyle(Color(theme.text)).lineLimit(1)
                    Spacer(minLength: theme.z(8))
                    if !command.keys.isEmpty { KeyCap(keys: command.keys, theme: theme) }
                }
                .frame(height: theme.z(22))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: theme.z(6)) {
            Text(tile.title).font(theme.font(11, weight: .medium)).foregroundStyle(Color(theme.secondaryText))
            Text(state?.content?.type?.rawValue ?? tile.typeName)
                .font(theme.font(9.5, weight: .medium, mono: true))
                .foregroundStyle(Color(theme.tertiaryText))
                .padding(.horizontal, theme.z(5))
                .padding(.vertical, theme.z(1))
                .background(Color(theme.well), in: RoundedRectangle(cornerRadius: theme.z(4)))
            Spacer()
            if state?.error != nil {
                Text("stale").font(theme.font(10.5, weight: .medium)).foregroundStyle(Color(theme.warning))
            } else if tile.mode == .stream {
                Text("live").font(theme.font(10.5)).foregroundStyle(Color(theme.tertiaryText))
            } else if let updated = state?.updated {
                Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                    .font(theme.font(10.5))
                    .foregroundStyle(Color(theme.tertiaryText))
            }
        }
    }
}
