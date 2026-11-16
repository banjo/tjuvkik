import Foundation

/// A few numbers, each against its last period: `{ "stats": [{ "label": "Merged", "value": "12" }] }`.
/// An s tile shows the first, m the first three, l six.
public struct StatsContent: Equatable, Sendable, Decodable {
    public struct Stat: Equatable, Sendable, Decodable {
        public var label: String?
        public var value: String
        public var unit: String?
        /// The change, like "▲ 4" or "62%".
        public var delta: String?
        /// The delta's color. The script decides, since up isn't always good.
        public var tone: Tone?
        /// What the delta is against, like "vs last week".
        public var vs: String?

        public init(label: String? = nil, value: String, unit: String? = nil, delta: String? = nil, tone: Tone? = nil, vs: String? = nil) {
            self.label = label
            self.value = value
            self.unit = unit
            self.delta = delta
            self.tone = tone
            self.vs = vs
        }

        private enum CodingKeys: String, CodingKey { case label, value, unit, delta, tone, vs }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            label = try container.decodeIfPresent(String.self, forKey: .label)
            value = try container.decodeText(forKey: .value)
            unit = try container.decodeIfPresent(String.self, forKey: .unit)
            delta = try container.decodeTextIfPresent(forKey: .delta)
            tone = try container.decodeIfPresent(Tone.self, forKey: .tone)
            vs = try container.decodeIfPresent(String.self, forKey: .vs)
        }
    }

    public var stats: [Stat]
    public var extras: PanelExtras

    public init(stats: [Stat], extras: PanelExtras = PanelExtras()) {
        self.stats = stats
        self.extras = extras
    }

    private enum CodingKeys: String, CodingKey { case stats }

    public init(from decoder: any Decoder) throws {
        stats = try decoder.container(keyedBy: CodingKeys.self).decodeOneOrMany(Stat.self, forKey: .stats)
        extras = try PanelExtras(from: decoder)
    }
}
