import Foundation

// The files as written: everything optional, enums as strings, so validation can report each
// problem with its file and path instead of failing on the first one.

/// `config.jsonc`
struct RawConfig: Decodable {
    var view: String?
    var layout: String?
    var theme: String?
    var trigger: RawTrigger?
    var launchAtLogin: Bool?
    var menuBar: OneOrMany?
    var pause: RawPause?
    var panels: [RawPanelRef]?
}

/// A string or an array of strings.
struct OneOrMany: Decodable {
    var values: [String]

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) { values = [value] } else { values = try container.decode([String].self) }
    }
}

struct RawTrigger: Decodable {
    var key: String?
    var shortcut: String?
    var mode: String?
    var holdMs: Int?
}

struct RawPause: Decodable {
    var whenLocked: Bool?
    var onLowPower: Bool?
}

/// `background`: a duration, or true or false.
enum RawBackground: Decodable {
    case flag(Bool)
    case duration(String)

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let flag = try? container.decode(Bool.self) {
            self = .flag(flag)
        } else if let text = try? container.decode(String.self) {
            self = .duration(text)
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: #"expected a duration like "5m", true or false"#))
        }
    }
}

/// An entry in `config.jsonc`'s `panels`: which panel, and optionally its size here.
struct RawPanelRef: Decodable {
    var panel: String?
    var size: String?
    var background: RawBackground?
    var show: Bool?
}

/// `panels/<name>/panel.jsonc`
struct RawPanel: Decodable {
    var type: String?
    var mode: String?
    var title: String?
    var description: String?
    var author: String?
    var version: String?
    var requires: [String]?
    var command: String?
    var every: String?
    var timeout: String?
    var size: String?
    var history: Int?
    var file: String?
    var background: RawBackground?
}

/// `themes/<name>.jsonc`
struct RawTheme: Decodable {
    var extends: String?
    var appearance: String?
    var blur: Bool?
    var radius: Double?
    var panel: String?
    var well: String?
    var text: String?
    var secondaryText: String?
    var tertiaryText: String?
    var line: String?
    var warning: String?
    var error: String?
    var success: String?
    var info: String?
    var accent: String?
}
