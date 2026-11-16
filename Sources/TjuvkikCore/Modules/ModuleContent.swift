import Foundation

/// What a panel shows. Tiles render by content type, so a new panel type only has to produce one
/// of these. Spotlight will render the same content as a list and a preview.
public enum ModuleContent: Equatable, Sendable {
    case rows(RowsContent)
    case text(String)
    /// Text where the newest lines are last and matter most, like a log: shown from the bottom.
    case tail(String)
    case stats(StatsContent)

    /// The type it's drawn as, or nil for rows and plain text.
    public var type: ContentType? {
        switch self {
        case .rows, .text, .tail: nil
        case .stats: .stats
        }
    }

    /// What the menu bar shows for this panel, or nil for nothing.
    public var menuBar: RowsContent.MenuBar? {
        switch self {
        case .rows(let rows): rows.menuBar
        case .text, .tail: nil
        case .stats(let content): content.extras.menuBar
        }
    }
}

/// Colors by meaning; each theme maps them to a color.
public enum Tone: String, Equatable, Sendable, CaseIterable, Decodable {
    case normal, muted, warning, error, success, info, accent

    /// Unknown tones read as normal, so a script written for a later version still renders.
    public init(from decoder: any Decoder) throws {
        self = Tone(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .normal
    }
}

/// A script panel's output.
public struct RowsContent: Equatable, Sendable, Decodable {
    public struct Hero: Equatable, Sendable, Decodable {
        public var value: String
        public var label: String?
        public var tone: Tone?
    }

    /// A small count in the summary line, like "❓ 2 waiting".
    public struct Chip: Equatable, Sendable, Decodable {
        public var icon: String?
        public var value: String?
        public var label: String?
        public var tone: Tone?
    }

    public struct Row: Equatable, Sendable, Decodable {
        public var icon: String?
        public var title: String
        public var subtitle: String?
        public var trailing: String?
        public var tone: Tone?
        /// A heading shown above the first row of each run of rows with the same group.
        public var group: String?
        /// A line under the row, in the row's tone, for what needs attention.
        public var note: String?
        /// Opened when the row is picked in the menu.
        public var url: String?
        /// Run when the row is picked in the menu, in the panel's folder. Wins over `url`.
        public var command: String?

        public init(icon: String? = nil, title: String, subtitle: String? = nil, trailing: String? = nil, tone: Tone? = nil,
                    group: String? = nil, note: String? = nil, url: String? = nil, command: String? = nil) {
            self.command = command
            self.icon = icon
            self.title = title
            self.subtitle = subtitle
            self.trailing = trailing
            self.tone = tone
            self.group = group
            self.note = note
            self.url = url
        }
    }

    /// What the panel shows in the menu bar, when it's picked in `config.jsonc`'s `menuBar`.
    public struct MenuBar: Equatable, Sendable, Decodable {
        public var icon: String?
        public var text: String?
        public var tone: Tone?
        /// Rows in the menu, under the panel's title.
        public var menu: [Row]?

        public init(icon: String? = nil, text: String? = nil, tone: Tone? = nil, menu: [Row]? = nil) {
            self.icon = icon
            self.text = text
            self.tone = tone
            self.menu = menu
        }

        /// What goes next to the icon: "❓ 2".
        public var title: String {
            [icon, text].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        }
    }

    public enum MenuBarSetting: Equatable, Sendable {
        /// Not set: the first summary chip, and the summary in the menu.
        case automatic
        /// `null`: nothing.
        case hidden
        case custom(MenuBar)
    }

    public var hero: Hero?
    public var summary: [Chip]?
    /// 0 to 1.
    public var progress: Double?
    public var rows: [Row]
    public var menuBarSetting: MenuBarSetting

    public init(hero: Hero? = nil, summary: [Chip]? = nil, progress: Double? = nil, rows: [Row], menuBar: MenuBarSetting = .automatic) {
        self.hero = hero
        self.summary = summary
        self.progress = progress
        self.rows = rows
        self.menuBarSetting = menuBar
    }

    private enum CodingKeys: String, CodingKey { case hero, progress, rows }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hero = try container.decodeIfPresent(Hero.self, forKey: .hero)
        progress = try container.decodeIfPresent(Double.self, forKey: .progress)
        rows = try container.decode([Row].self, forKey: .rows)
        let extras = try PanelExtras(from: decoder)
        summary = extras.summary
        menuBarSetting = extras.menuBarSetting
    }

    /// What the menu bar shows for this panel, or nil for nothing.
    public var menuBar: MenuBar? {
        PanelExtras(summary: summary, menuBar: menuBarSetting).menuBar
    }
}

public enum ScriptOutput {
    /// Reads the JSON a script prints, as `type` or, without one, as the type its top-level key
    /// names, else rows. The message says what's wrong, for the tile to show.
    public static func content(_ data: Data, as type: ContentType? = nil) -> Result<ModuleContent, ScriptOutputError> {
        switch type ?? (try? decoder.decode(KeyProbe.self, from: data)).flatMap(ContentType.detect) {
        case nil: parse(data).map(ModuleContent.rows)
        case .stats: decode(StatsContent.self, from: data).map(ModuleContent.stats)
        }
    }

    /// Reads the JSON a script prints as rows.
    public static func parse(_ data: Data) -> Result<RowsContent, ScriptOutputError> {
        decode(RowsContent.self, from: data).map { content in
            var content = content
            content.progress = content.progress.map { min(max($0, 0), 1) }
            return content
        }
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        return decoder
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> Result<T, ScriptOutputError> {
        do {
            return .success(try decoder.decode(T.self, from: data))
        } catch let DecodingError.keyNotFound(key, context) {
            let at = path(context.codingPath)
            return .failure(ScriptOutputError(message: "missing \"\(key.stringValue)\"\(at.isEmpty ? "" : " in \(at)")"))
        } catch let DecodingError.typeMismatch(_, context) {
            return .failure(ScriptOutputError(message: "wrong type at \(path(context.codingPath))"))
        } catch let DecodingError.valueNotFound(_, context) {
            return .failure(ScriptOutputError(message: "wrong type at \(path(context.codingPath))"))
        } catch {
            let text = String(decoding: data.prefix(80), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(ScriptOutputError(message: text.isEmpty ? "printed nothing" : "didn't print JSON: \(text)"))
        }
    }

    /// `rows[0].title`
    private static func path(_ codingPath: [any CodingKey]) -> String {
        let at = codingPath.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }.joined()
        return String(at.dropFirst(at.hasPrefix(".") ? 1 : 0))
    }
}

public struct ScriptOutputError: Error, Equatable, Sendable {
    public var message: String
}

public enum TerminalText {
    /// Removes color codes, cursor movement and other escape sequences, and carriage returns.
    public static func clean(_ text: String) -> String {
        text
            .replacing(/\u{1B}\][^\u{07}\u{1B}]*(\u{07}|\u{1B}\\)/, with: "")
            .replacing(/\u{1B}\[[0-9;?]*[ -\/]*[@-~]/, with: "")
            .replacing(/\u{1B}[@-_]/, with: "")
            .replacing("\r\n", with: "\n")
            .replacing("\r", with: "")
    }
}
