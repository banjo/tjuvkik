import Foundation

/// How full, how far, how close to a limit:
/// `{ "meters": [{ "label": "Macintosh HD", "value": 412, "max": 494, "mark": 450 }], "footer": "82 GB free" }`.
/// An s tile shows the first as a ring, m the first three with bars, l a list of bars.
public struct MetersContent: Equatable, Sendable, Decodable {
    public struct Meter: Equatable, Sendable, Decodable {
        public var label: String?
        /// The bar's fill, against `max`.
        public var value: Double
        /// What a full bar is. 100 when the script leaves it out, so `value` reads as a percentage.
        public var max: Double
        /// What the value says: the script's `text`, else the number, with % when there's no max.
        public var text: String
        /// What it's out of: the script's `of`, else `max` when the script gave one.
        public var of: String?
        /// A limit tick on the bar, on the same scale as `value`.
        public var mark: Double?
        /// The bar's color. Accent when nil.
        public var tone: Tone?

        /// Without `max`, the value is a percentage: max is 100 and `text` gets a %.
        public init(label: String? = nil, value: Double, max: Double? = nil, text: String? = nil, of: String? = nil, mark: Double? = nil, tone: Tone? = nil) {
            self.label = label
            self.value = value
            self.max = max ?? 100
            self.text = text ?? (max == nil ? "\(value.text)%" : value.text)
            self.of = of ?? max?.text
            self.mark = mark
            self.tone = tone
        }

        private enum CodingKeys: String, CodingKey { case label, value, max, text, of, mark, tone }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                label: try container.decodeTextIfPresent(forKey: .label),
                value: try container.decodeMeterNumber(forKey: .value),
                max: try container.decodeMeterNumberIfPresent(forKey: .max),
                text: try container.decodeTextIfPresent(forKey: .text),
                of: try container.decodeTextIfPresent(forKey: .of),
                mark: try container.decodeMeterNumberIfPresent(forKey: .mark),
                tone: try container.decodeIfPresent(Tone.self, forKey: .tone)
            )
        }

        /// How full the bar is, 0 to 1.
        public var fraction: Double { Self.fraction(value, of: max) }

        /// Where the limit tick sits, 0 to 1, or nil for none.
        public var markFraction: Double? { mark.map { Self.fraction($0, of: max) } }

        /// `value / max`, kept within 0...1. A max of zero or less, or a value that isn't a number,
        /// is an empty bar.
        static func fraction(_ value: Double, of max: Double) -> Double {
            guard max > 0, value.isFinite else { return 0 }
            return Swift.min(Swift.max(value / max, 0), 1)
        }
    }

    public var meters: [Meter]
    /// A line under the bars at size l, like "82 GB free · Time Machine 2h ago".
    public var footer: String?
    public var extras: PanelExtras

    public init(meters: [Meter], footer: String? = nil, extras: PanelExtras = PanelExtras()) {
        self.meters = meters
        self.footer = footer
        self.extras = extras
    }

    private enum CodingKeys: String, CodingKey { case meters, footer }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        meters = try container.decodeOneOrMany(Meter.self, forKey: .meters)
        footer = try container.decodeTextIfPresent(forKey: .footer)
        extras = try PanelExtras(from: decoder)
    }
}

extension KeyedDecodingContainer {
    /// A number, or text that reads as one, since scripts print both: `412`, `"412"`, `"83%"`,
    /// `"4,212"`.
    fileprivate func decodeMeterNumber(forKey key: Key) throws -> Double {
        if let number = try? decode(Double.self, forKey: key) { return number }
        let text = try decode(String.self, forKey: key)
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "% "))
        guard let number = Double(cleaned) else {
            throw DecodingError.typeMismatch(
                Double.self,
                DecodingError.Context(codingPath: codingPath + [key], debugDescription: "not a number: \(text)")
            )
        }
        return number
    }

    fileprivate func decodeMeterNumberIfPresent(forKey key: Key) throws -> Double? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        return try decodeMeterNumber(forKey: key)
    }
}
