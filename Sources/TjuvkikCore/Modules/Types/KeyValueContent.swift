import Foundation

/// Exact facts, grouped: `{ "pairs": [{ "section": "Kubernetes" }, { "key": "Context", "value": "aks-prod-weu" }] }`.
/// An s tile shows label above value, m two columns of pairs, l one list with sections.
public struct KeyValueContent: Equatable, Sendable, Decodable {
    public struct Pair: Equatable, Sendable {
        public var key: String
        /// Shown monospaced and cut in the middle, so the ends of IDs and paths stay visible.
        public var value: String
        public var tone: Tone?
        /// Draws the value on a tinted capsule in its tone. Needs a tone.
        public var pill: Bool

        public init(key: String, value: String, tone: Tone? = nil, pill: Bool = false) {
            self.key = key
            self.value = value
            self.tone = tone
            self.pill = pill
        }
    }

    /// One item of `pairs`: a heading, or a key and its value.
    public enum Entry: Equatable, Sendable, Decodable {
        case section(String)
        case pair(Pair)

        private enum CodingKeys: String, CodingKey { case section, key, value, tone, pill }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let title = try container.decodeTextIfPresent(forKey: .section) {
                self = .section(title)
                return
            }
            let key = try container.decodeText(forKey: .key)
            let value: String
            if let flag = try? container.decode(Bool.self, forKey: .value) {
                value = flag ? "true" : "false"
            } else {
                value = try container.decodeText(forKey: .value)
            }
            let tone = try container.decodeIfPresent(Tone.self, forKey: .tone)
            let pill = (try? container.decodeIfPresent(Bool.self, forKey: .pill)) ?? false
            self = .pair(Pair(key: key, value: value, tone: tone, pill: pill))
        }
    }

    /// A heading and the pairs under it. Pairs before the first heading have none.
    public struct Section: Equatable, Sendable {
        public var title: String?
        public var pairs: [Pair]

        public init(title: String? = nil, pairs: [Pair]) {
            self.title = title
            self.pairs = pairs
        }
    }

    public var entries: [Entry]
    public var extras: PanelExtras

    public init(entries: [Entry], extras: PanelExtras = PanelExtras()) {
        self.entries = entries
        self.extras = extras
    }

    private enum CodingKeys: String, CodingKey { case pairs }

    public init(from decoder: any Decoder) throws {
        entries = try decoder.container(keyedBy: CodingKeys.self).decodeOneOrMany(Entry.self, forKey: .pairs)
        extras = try PanelExtras(from: decoder)
    }

    /// Every pair, without headings.
    public var pairs: [Pair] {
        entries.compactMap { entry -> Pair? in
            guard case .pair(let pair) = entry else { return nil }
            return pair
        }
    }

    /// The pairs under their headings. Headings with no pairs under them are dropped.
    public var sections: [Section] {
        Self.group(Self.trimmed(entries))
    }

    /// The sections split into two columns of about as many lines each, a heading counting as a
    /// line. A heading never ends the left column; a section cut in two goes on in the right
    /// column without its heading.
    public var columns: (left: [Section], right: [Section]) {
        let lines = Self.trimmed(entries)
        var split = (lines.count + 1) / 2
        if split > 0, case .section = lines[split - 1] { split -= 1 }
        return (Self.group(Array(lines[..<split])), Self.group(Array(lines[split...])))
    }

    /// Without headings that have no pair before the next heading or the end.
    private static func trimmed(_ entries: [Entry]) -> [Entry] {
        entries.indices.compactMap { index -> Entry? in
            guard case .section = entries[index] else { return entries[index] }
            let next = entries.index(after: index)
            guard next < entries.endIndex, case .pair = entries[next] else { return nil }
            return entries[index]
        }
    }

    private static func group(_ entries: [Entry]) -> [Section] {
        var sections: [Section] = []
        for entry in entries {
            switch entry {
            case .section(let title):
                sections.append(Section(title: title, pairs: []))
            case .pair(let pair):
                if sections.isEmpty { sections.append(Section(pairs: [])) }
                sections[sections.count - 1].pairs.append(pair)
            }
        }
        return sections.filter { !$0.pairs.isEmpty }
    }
}
