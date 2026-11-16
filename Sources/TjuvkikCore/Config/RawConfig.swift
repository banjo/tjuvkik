import Foundation

// The files as written: everything optional, enums as strings, so validation can report each
// problem with its file and path instead of failing on the first one.

/// `config.json`
struct RawConfig: Decodable {
    var view: String?
    var layout: String?
    var theme: String?
    var trigger: RawTrigger?
    var launchAtLogin: Bool?
    var panels: [RawPanelRef]?
}

struct RawTrigger: Decodable {
    var holdMs: Int?
}

/// An entry in `config.json`'s `panels`: which panel, and optionally its size here.
struct RawPanelRef: Decodable {
    var panel: String?
    var size: String?
}

/// `panels/<name>/panel.json`
struct RawPanel: Decodable {
    var type: String?
    var title: String?
    var command: String?
    var every: String?
    var timeout: String?
    var size: String?
}

/// `themes/<name>.json`
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
