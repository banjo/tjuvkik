import Foundation

/// The file as written: everything optional, enums as strings, so validation can report each
/// problem with its path instead of failing on the first one.
struct RawConfig: Decodable {
    var view: String?
    var layout: String?
    var theme: String?
    var trigger: RawTrigger?
    var launchAtLogin: Bool?
    var themes: [String: RawTheme]?
    var tiles: [RawTile]?
}

struct RawTrigger: Decodable {
    var holdMs: Int?
}

struct RawTile: Decodable {
    var module: String?
    var type: String?
    var title: String?
    var size: String?
    var every: String?
    var timeout: String?
    var command: String?
}

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
