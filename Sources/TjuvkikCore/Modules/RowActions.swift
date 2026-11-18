import Foundation

/// What a row offers besides a click, in the glance: `actionTitle` names the click in the hint bar,
/// and `actions` are listed by ⌘K, each run directly with ⌘ and its `key`.
///
/// ```json
/// { "title": "feat: export filters", "url": "https://…", "actionTitle": "Open PR",
///   "actions": [{ "title": "Approve", "command": "gh pr review 1284 --approve", "key": "a" },
///               { "title": "Copy branch", "copy": "feat/export-filters" }] }
/// ```
public struct RowActions: Equatable, Sendable, Decodable {
    public struct Action: Equatable, Sendable, Decodable {
        public var title: String
        /// Run in the panel's folder. Wins over `url` and `copy`.
        public var command: String?
        /// Opened. Wins over `copy`.
        public var url: String?
        /// Put on the clipboard.
        public var copy: String?
        /// A letter or digit: ⌘ and it runs the action while the row is picked. Not c, k, o or r,
        /// which the glance uses.
        public var key: String?

        public init(title: String, command: String? = nil, url: String? = nil, copy: String? = nil, key: String? = nil) {
            self.title = title
            self.command = command
            self.url = url
            self.copy = copy
            self.key = key
        }

        private enum CodingKeys: String, CodingKey { case title, command, url, copy, key }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decode(String.self, forKey: .title)
            command = try container.decodeIfPresent(String.self, forKey: .command)
            url = try container.decodeIfPresent(String.self, forKey: .url)
            copy = try container.decodeIfPresent(String.self, forKey: .copy)
            let key = try container.decodeIfPresent(String.self, forKey: .key)?.lowercased()
            self.key = key.flatMap { Self.usable($0) ? $0 : nil }
        }

        /// The keys the glance keeps for itself: copy, actions, open config, refresh.
        public static let reserved: Set<String> = ["c", "k", "o", "r"]

        static func usable(_ key: String) -> Bool {
            guard key.count == 1, let character = key.first, character.isASCII, character.isLetter || character.isNumber else { return false }
            return !reserved.contains(key)
        }
    }

    /// What the hint bar calls a click, like "Jump to session". Default: Run or Open.
    public var title: String?
    public var actions: [Action]

    public init(title: String? = nil, actions: [Action] = []) {
        self.title = title
        self.actions = actions
    }

    public var isEmpty: Bool { title == nil && actions.isEmpty }

    private enum CodingKeys: String, CodingKey {
        case title = "actionTitle"
        case actions
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        actions = try container.decodeIfPresent([Action].self, forKey: .actions) ?? []
    }
}
