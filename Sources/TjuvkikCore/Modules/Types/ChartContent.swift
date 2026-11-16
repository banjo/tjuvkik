import Foundation

/// One number and where it's heading: `{ "chart": { "value": "64", "series": [31, 28, 35, 64] } }`.
/// An s tile shows the value over a sparkline, m the value left of the chart, l the chart with
/// axes, a threshold line and min/avg/max.
public struct ChartContent: Equatable, Sendable, Decodable {
    /// The change, in its tone: "▲ 22 pts in 10m".
    public struct Delta: Equatable, Sendable, Decodable {
        public var text: String
        public var tone: Tone?

        public init(text: String, tone: Tone? = nil) {
            self.text = text
            self.tone = tone
        }

        private enum CodingKeys: String, CodingKey { case text, tone }

        /// An object, or just the text: `"delta": "▲ 3"`.
        public init(from decoder: any Decoder) throws {
            if let single = try? decoder.singleValueContainer() {
                if let text = try? single.decode(String.self) {
                    self = Delta(text: text)
                    return
                }
                if let number = try? single.decode(Double.self) {
                    self = Delta(text: number.text)
                    return
                }
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            text = try container.decodeText(forKey: .text)
            tone = try container.decodeIfPresent(Tone.self, forKey: .tone)
        }
    }

    /// The current value, as shown: "64", "4:12".
    public var value: String
    public var unit: String?
    public var label: String?
    public var delta: Delta?
    /// Oldest first.
    public var series: [Double]
    /// The bottom of the scale; without it, the lowest value.
    public var min: Double?
    /// The top of the scale; without it, the highest value.
    public var max: Double?
    /// A dashed line on the l chart, like a limit.
    public var threshold: Double?
    /// Labels under the l chart, spread from left to right: `["−60m", "−30m", "now"]`.
    public var axis: [String]
    /// The line's color. Accent by default.
    public var tone: Tone?
    public var extras: PanelExtras

    public init(
        value: String, unit: String? = nil, label: String? = nil, delta: Delta? = nil, series: [Double] = [],
        min: Double? = nil, max: Double? = nil, threshold: Double? = nil, axis: [String] = [], tone: Tone? = nil,
        extras: PanelExtras = PanelExtras()
    ) {
        self.value = value
        self.unit = unit
        self.label = label
        self.delta = delta
        self.series = series
        self.min = min
        self.max = max
        self.threshold = threshold
        self.axis = axis
        self.tone = tone
        self.extras = extras
    }

    private enum OuterKeys: String, CodingKey { case chart }
    private enum CodingKeys: String, CodingKey { case value, unit, label, delta, series, min, max, threshold, axis, tone }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: OuterKeys.self).nestedContainer(keyedBy: CodingKeys.self, forKey: .chart)
        series = try container.decodeIfPresent([ChartNumber].self, forKey: .series)?.compactMap(\.value) ?? []
        // Without a value, the last point is the current one.
        if let value = try container.decodeTextIfPresent(forKey: .value) {
            self.value = value
        } else if let last = series.last {
            value = last.text
        } else {
            throw DecodingError.keyNotFound(CodingKeys.value, .init(codingPath: container.codingPath, debugDescription: "missing value"))
        }
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        delta = try container.decodeIfPresent(Delta.self, forKey: .delta)
        min = try container.decodeIfPresent(ChartNumber.self, forKey: .min)?.value
        max = try container.decodeIfPresent(ChartNumber.self, forKey: .max)?.value
        threshold = try container.decodeIfPresent(ChartNumber.self, forKey: .threshold)?.value
        if container.contains(.axis), try !container.decodeNil(forKey: .axis) {
            axis = try container.decodeOneOrMany(ChartLabel.self, forKey: .axis).map(\.text)
        } else {
            axis = []
        }
        tone = try container.decodeIfPresent(Tone.self, forKey: .tone)
        extras = try PanelExtras(from: decoder)
    }

    /// The value as a number, when it is one: what `history` keeps.
    public var number: Double? {
        ChartNumber.parse(value)
    }

    /// The scale the chart is drawn on.
    public var scale: ChartScale {
        ChartScale(series: series, min: min, max: max, threshold: threshold)
    }

    /// The lowest, average and highest value, or nil without a series.
    public var summary: ChartSummary? {
        ChartSummary(series)
    }

    /// A number in the chart's precision, with its unit: `18%`, `0.12%`, `19.1 GB`.
    public func format(_ number: Double) -> String {
        let decimals = ChartNumber.parse(value) != nil ? ChartFormat.decimals(in: value) : ChartFormat.decimals(for: number)
        return ChartFormat.text(number, decimals: decimals) + ChartFormat.unitSuffix(unit)
    }
}

/// The range a chart is drawn in, padded a little so the line doesn't touch the edges.
public struct ChartScale: Equatable, Sendable {
    public var lower: Double
    public var upper: Double

    public init(lower: Double, upper: Double) {
        self.lower = lower
        self.upper = upper
    }

    /// From `min` and `max`, else the series' range. A threshold without them is kept in view.
    /// Pads 8% of the range on both ends, or 1 when the range is flat.
    public init(series: [Double], min: Double? = nil, max: Double? = nil, threshold: Double? = nil) {
        let points = series + (threshold.map { [$0] } ?? [])
        var low = min ?? points.min() ?? 0
        var high = max ?? points.max() ?? 1
        if low > high { swap(&low, &high) }
        let pad = (high - low) * 0.08
        let padding = pad > 0 ? pad : 1
        self.init(lower: low - padding, upper: high + padding)
    }

    /// Where a value sits, from 0 at the bottom to 1 at the top, kept inside.
    public func fraction(_ value: Double) -> Double {
        guard upper > lower else { return 0.5 }
        return Swift.min(Swift.max((value - lower) / (upper - lower), 0), 1)
    }

    /// The series as points from (0, bottom) to (1, top), evenly spread, oldest left. A single
    /// value is a flat line.
    public func points(_ series: [Double]) -> [ChartPoint] {
        switch series.count {
        case 0: return []
        case 1: return [ChartPoint(x: 0, y: fraction(series[0])), ChartPoint(x: 1, y: fraction(series[0]))]
        default:
            let step = 1 / Double(series.count - 1)
            return series.enumerated().map { ChartPoint(x: Double($0.offset) * step, y: fraction($0.element)) }
        }
    }
}

/// A point on the chart, 0 to 1 on both axes, y up.
public struct ChartPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// The l chart's footer: min, avg, max.
public struct ChartSummary: Equatable, Sendable {
    public var min: Double
    public var average: Double
    public var max: Double

    public init(min: Double, average: Double, max: Double) {
        self.min = min
        self.average = average
        self.max = max
    }

    public init?(_ series: [Double]) {
        guard let low = series.min(), let high = series.max() else { return nil }
        self.init(min: low, average: series.reduce(0, +) / Double(series.count), max: high)
    }
}

/// Keeps the series for a script that prints only the current value: `"history": 60` in
/// panel.jsonc.
public enum ChartHistory {
    /// The most values `history` can keep.
    public static let range = 2...1000

    /// The series with `value` added last, keeping the newest `limit`.
    public static func append(_ value: Double, to series: [Double], limit: Int) -> [Double] {
        let limit = Swift.max(limit, 1)
        let series = series + [value]
        return Array(series.suffix(limit))
    }

    /// Fills in the series of a chart that printed none, from the values kept so far, and returns
    /// what to keep. Other content, a chart with its own series, or a value that isn't a number
    /// is left as is.
    public static func apply(to content: ModuleContent, kept: [Double], limit: Int?) -> (content: ModuleContent, kept: [Double]) {
        guard let limit, case .chart(var chart) = content, chart.series.isEmpty, let number = chart.number else {
            return (content, kept)
        }
        let series = append(number, to: kept, limit: limit)
        chart.series = series
        return (.chart(chart), series)
    }
}

enum ChartFormat {
    /// Digits after the point in `text`: 0 for "64", 2 for "0.12". At most 3.
    static func decimals(in text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let dot = trimmed.firstIndex(of: ".") else { return 0 }
        return Swift.min(trimmed[trimmed.index(after: dot)...].prefix { $0.isNumber }.count, 3)
    }

    /// Enough digits to tell values apart: 0 from 100, 1 from 10, else 2.
    static func decimals(for number: Double) -> Int {
        switch abs(number) {
        case 100...: 0
        case 10...: 1
        default: 2
        }
    }

    /// `number` rounded to `decimals`, without trailing zeros: 34.2, 18, 0.1.
    static func text(_ number: Double, decimals: Int) -> String {
        let factor = pow(10, Double(decimals))
        let rounded = (number * factor).rounded() / factor
        return (rounded == 0 ? 0 : rounded).text
    }

    /// `%` and `ms` stick to the number, words get a space: "18%", "19 GB".
    static func unitSuffix(_ unit: String?) -> String {
        guard let unit = unit?.trimmingCharacters(in: .whitespaces), !unit.isEmpty else { return "" }
        return unit.count > 2 || unit.first?.isUppercase == true ? " \(unit)" : unit
    }
}

/// A number, or a number written as text: `31`, `"31"`. Null reads as nothing.
private struct ChartNumber: Decodable {
    var value: Double?

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
        } else if let number = try? container.decode(Double.self) {
            value = number.isFinite ? number : nil
        } else if let parsed = Self.parse(try container.decode(String.self)) {
            value = parsed
        } else {
            throw DecodingError.typeMismatch(Double.self, .init(codingPath: decoder.codingPath, debugDescription: "not a number"))
        }
    }

    static func parse(_ text: String) -> Double? {
        guard let number = Double(text.trimmingCharacters(in: .whitespaces)), number.isFinite else { return nil }
        return number
    }
}

/// An axis label, as text or a number.
private struct ChartLabel: Decodable {
    var text: String

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) { text = number.text } else { text = try container.decode(String.self) }
    }
}
