import Foundation

/// How a script panel's output is drawn, besides plain rows. A script picks one with its
/// top-level key (`{ "stats": [...] }`), or the panel sets it with `"type"` in panel.jsonc.
public enum ContentType: String, CaseIterable, Sendable {
    // Order matters: the first that matches wins, so feed comes before checklist (both use `items`).
    case chart
    case meters
    case grid
    case timeline
    case stats
    case markdown
    case keyvalue
    case table
    case feed
    case checklist

    /// The type a script's output is, from its top-level keys. Nil means rows.
    static func detect(_ probe: KeyProbe) -> ContentType? {
        allCases.first { $0.matches(probe) }
    }

    private func matches(_ probe: KeyProbe) -> Bool {
        switch self {
        case .chart: probe.keys.contains("chart")
        case .meters: probe.keys.contains("meters")
        case .grid: probe.keys.contains("grid")
        case .timeline: probe.keys.contains("timeline")
        case .stats: probe.keys.contains("stats")
        case .markdown: probe.keys.contains("markdown")
        case .keyvalue: probe.keys.contains("pairs")
        case .table: probe.keys.contains("columns")
        case .feed: probe.keys.contains("items") && (probe.itemKeys.contains("author") || probe.itemKeys.contains("text"))
        case .checklist: probe.keys.contains("items")
        }
    }
}

/// Reads only the shape of the output: its top-level keys, and the keys of the objects in
/// `items`, which more than one type uses.
struct KeyProbe: Decodable {
    var keys: Set<String>
    var itemKeys: Set<String>

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        keys = Set(container.allKeys.map(\.stringValue))
        let items = (try? container.decode([Item].self, forKey: AnyKey(stringValue: "items"))) ?? []
        itemKeys = items.reduce(into: []) { $0.formUnion($1.keys) }
    }

    private struct Item: Decodable {
        var keys: Set<String>

        init(from decoder: any Decoder) throws {
            keys = (try? Set(decoder.container(keyedBy: AnyKey.self).allKeys.map(\.stringValue))) ?? []
        }
    }
}

struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

extension KeyedDecodingContainer {
    /// A string, or a number written as text, since scripts print both: `"value": 12`.
    func decodeText(forKey key: Key) throws -> String {
        if let number = try? decode(Double.self, forKey: key) { return number.text }
        return try decode(String.self, forKey: key)
    }

    func decodeTextIfPresent(forKey key: Key) throws -> String? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        return try decodeText(forKey: key)
    }

    /// One value or an array of them.
    func decodeOneOrMany<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> [T] {
        if let one = try? decode(T.self, forKey: key) { return [one] }
        return try decode([T].self, forKey: key)
    }
}

extension Double {
    /// `12` for 12.0, `12.5` for 12.5.
    var text: String {
        rounded() == self && abs(self) < 1e15 ? String(Int(self)) : String(self)
    }
}
