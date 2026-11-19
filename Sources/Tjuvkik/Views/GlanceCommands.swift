import AppKit
import SwiftUI
import TjuvkikCore

/// Something the keyboard can do with the focused row or tile.
struct GlanceCommand: Equatable {
    enum Kind: Equatable {
        /// What a click does.
        case click
        /// The row's url, though it has a command.
        case openURL
        case action(RowActions.Action)
        /// The row's url, or its title.
        case copy
        case refresh
        case openConfig
        case showInFinder
        /// The ⌘K list itself, for the hint bar.
        case menu
    }

    var title: String
    /// "↵", "⌘A", or empty for none.
    var keys: String
    var kind: Kind

    /// Everything for a row, or a tile when `row` is nil, in the order ⌘K lists them.
    static func all(for row: RowAction?) -> [GlanceCommand] {
        var commands: [GlanceCommand] = []
        if let row {
            if row.clicks {
                commands.append(GlanceCommand(title: row.actions.title ?? (row.hasCommand ? "Run" : "Open"), keys: "↵", kind: .click))
            }
            if row.hasCommand && row.hasURL {
                commands.append(GlanceCommand(title: "Open Link", keys: "⌥↵", kind: .openURL))
            }
            for action in row.actions.actions {
                commands.append(GlanceCommand(title: action.title, keys: action.key.map { "⌘\($0.uppercased())" } ?? "", kind: .action(action)))
            }
            commands.append(GlanceCommand(title: row.hasURL ? "Copy Link" : "Copy Title", keys: "⌘C", kind: .copy))
        }
        commands += [
            GlanceCommand(title: "Refresh", keys: "⌘R", kind: .refresh),
            GlanceCommand(title: "Open panel.jsonc", keys: "⌘O", kind: .openConfig),
            GlanceCommand(title: "Show in Finder", keys: "", kind: .showInFinder),
        ]
        return commands
    }

    /// What the hint bar shows: the click, actions with a key, then ⌘K and Esc.
    static func hints(for row: RowAction?) -> [GlanceCommand] {
        let all = all(for: row)
        var hints = all.filter { $0.kind == .click }
        hints += all.filter { if case .action = $0.kind { !$0.keys.isEmpty } else { false } }.prefix(3)
        if row == nil { hints.append(all[0]) }
        hints.append(GlanceCommand(title: "Actions", keys: "⌘K", kind: .menu))
        return hints
    }
}

/// The ⌘K list: the focused row's commands, one picked.
struct ActionMenu: Equatable {
    var commands: [GlanceCommand]
    var selected = 0
}

/// Under the board while the keyboard is in use: what the keys do for the focused row.
struct HintBar: View {
    let hints: [GlanceCommand]
    let jumpKey: Config.JumpKey
    let theme: Theme

    var body: some View {
        HStack(spacing: theme.z(14)) {
            ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                HStack(spacing: theme.z(5)) {
                    KeyCap(keys: hint.keys, theme: theme)
                    Text(hint.title).font(theme.font(11.5)).foregroundStyle(Color(theme.secondaryText)).lineLimit(1)
                }
            }
            HStack(spacing: theme.z(5)) {
                KeyCap(keys: "⇥", theme: theme)
                if let symbol = jumpKey.symbol { KeyCap(keys: "\(symbol)←↑↓→", theme: theme) }
                Text("Panels").font(theme.font(11.5)).foregroundStyle(Color(theme.secondaryText))
            }
            HStack(spacing: theme.z(5)) {
                KeyCap(keys: "esc", theme: theme)
                Text("Close").font(theme.font(11.5)).foregroundStyle(Color(theme.secondaryText))
            }
        }
        .padding(.horizontal, theme.z(12))
        .frame(height: theme.z(28))
        .background(GlassCapsule(theme: theme))
    }
}

struct KeyCap: View {
    let keys: String
    let theme: Theme

    var body: some View {
        Text(keys)
            .font(theme.font(10.5, weight: .medium, mono: true))
            .foregroundStyle(Color(theme.text))
            .padding(.horizontal, theme.z(5))
            .frame(minWidth: theme.z(18), minHeight: theme.z(17))
            .background(Color(theme.well), in: RoundedRectangle(cornerRadius: theme.z(4), style: .continuous))
    }
}

/// The ⌘K list, next to the focused row.
struct ActionMenuView: View {
    let menu: ActionMenu
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.z(1)) {
            ForEach(Array(menu.commands.enumerated()), id: \.offset) { index, command in
                HStack(spacing: theme.z(10)) {
                    Text(command.title).font(theme.font(12.5)).foregroundStyle(Color(theme.text)).lineLimit(1)
                    Spacer(minLength: theme.z(12))
                    if !command.keys.isEmpty {
                        Text(command.keys).font(theme.font(11, mono: true)).foregroundStyle(Color(theme.tertiaryText))
                    }
                }
                .padding(.horizontal, theme.z(9))
                .frame(height: theme.z(26))
                .background(index == menu.selected ? Color(theme.accent).opacity(0.22) : .clear,
                            in: RoundedRectangle(cornerRadius: theme.z(6), style: .continuous))
            }
        }
        .padding(theme.z(5))
        .frame(width: theme.z(240))
        .background {
            ZStack {
                VisualEffect(cornerRadius: theme.z(10), appearance: theme.appearance, material: theme.material)
                RoundedRectangle(cornerRadius: theme.z(10), style: .continuous).fill(Color(theme.panel.opaque).opacity(0.85))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: theme.z(10), style: .continuous).strokeBorder(Color(theme.line), lineWidth: theme.z(1)))
        .shadow(color: .black.opacity(0.3), radius: theme.z(16), y: theme.z(8))
    }
}

private struct GlassCapsule: View {
    let theme: Theme

    var body: some View {
        ZStack {
            VisualEffect(cornerRadius: theme.z(14), appearance: theme.appearance, material: theme.material)
            RoundedRectangle(cornerRadius: theme.z(14), style: .continuous).fill(Color(theme.panel))
        }
    }
}
