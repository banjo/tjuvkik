import Foundation

/// Parses intervals like `30s`, `5m`, `1h` and `500ms` into seconds.
public enum Interval {
    private static let units: [(suffix: String, seconds: Double)] = [("ms", 0.001), ("s", 1), ("m", 60), ("h", 3600)]

    public static func seconds(_ text: String) -> Double? {
        let text = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard let unit = units.first(where: { text.hasSuffix($0.suffix) }),
              let value = Double(text.dropLast(unit.suffix.count)),
              value > 0, value.isFinite
        else { return nil }
        return value * unit.seconds
    }
}
