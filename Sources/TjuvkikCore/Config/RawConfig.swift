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

/// An entry in `config.jsonc`'s `panels`: which panel, and optionally its size here.
struct RawPanelRef: Decodable {
    var panel: String?
    var size: String?
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
