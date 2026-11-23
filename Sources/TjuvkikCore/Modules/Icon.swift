import Foundation

/// What a script's `icon` string draws: an emoji or short text as is, `sf:hammer.fill` as an SF
/// Symbol in the item's tone, `sf:gearshape:rotate` as one that moves, and `spinner` as the
/// system's loading indicator.
public enum Icon: Equatable, Sendable {
    case text(String)
    case symbol(String, effect: Effect?)
    case spinner

    /// How a symbol moves, over and over.
    public enum Effect: String, Equatable, Sendable, CaseIterable {
        case pulse, breathe, rotate, bounce, wiggle
    }

    public static let symbolPrefix = "sf:"
    public static let spinnerName = "spinner"

    /// Nil for nothing to draw. An unknown effect draws the symbol still, so a script written for
    /// a later version still renders.
    public init?(_ raw: String?) {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        if raw == Self.spinnerName {
            self = .spinner
        } else if raw.hasPrefix(Self.symbolPrefix) {
            let parts = raw.dropFirst(Self.symbolPrefix.count).split(separator: ":", maxSplits: 1).map(String.init)
            guard let name = parts.first, !name.isEmpty else { return nil }
            self = .symbol(name, effect: parts.count > 1 ? Effect(rawValue: parts[1]) : nil)
        } else {
            self = .text(raw)
        }
    }

    /// What to write where only text fits: the text, or nil for a symbol or spinner.
    public var text: String? {
        if case .text(let text) = self { text } else { nil }
    }

    /// What's wrong with `raw`, for `tjuvkik run`: an effect it doesn't know. Whether the symbol
    /// exists is up to the system, so the app checks that.
    public static func problem(_ raw: String) -> String? {
        guard raw.hasPrefix(symbolPrefix) else { return nil }
        let parts = raw.dropFirst(symbolPrefix.count).split(separator: ":", maxSplits: 1).map(String.init)
        guard let name = parts.first, !name.isEmpty else { return "icon \"\(raw)\" names no symbol" }
        if parts.count > 1, Effect(rawValue: parts[1]) == nil {
            let effects = Effect.allCases.map(\.rawValue).joined(separator: ", ")
            return "icon \"\(raw)\": unknown effect \"\(parts[1])\", use \(effects)"
        }
        return nil
    }
}

extension ModuleContent {
    /// Every `icon` the output sets: rows, summary, menu bar, its menu and feed items.
    public var icons: [String] {
        var icons: [String] = []
        let extras: PanelExtras? = switch self {
        case .rows(let content):
            PanelExtras(summary: content.summary, menuBar: content.menuBarSetting)
        case .text, .tail: nil
        case .chart(let content): content.extras
        case .meters(let content): content.extras
        case .grid(let content): content.extras
        case .timeline(let content): content.extras
        case .stats(let content): content.extras
        case .markdown(let content): content.extras
        case .keyvalue(let content): content.extras
        case .table(let content): content.extras
        case .feed(let content): content.extras
        case .checklist(let content): content.extras
        }
        if case .rows(let content) = self { icons += content.rows.compactMap(\.icon) }
        if case .feed(let content) = self { icons += content.items.compactMap(\.icon) }
        icons += extras?.summary?.compactMap(\.icon) ?? []
        if case .custom(let menuBar) = extras?.menuBarSetting {
            icons += [menuBar.icon].compactMap { $0 } + (menuBar.menu ?? []).compactMap(\.icon)
        }
        return icons.filter { !$0.isEmpty }
    }
}
