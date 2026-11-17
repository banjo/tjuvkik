import Foundation

// The files as written: everything optional, enums as strings, so validation can report each
// problem with its file and path instead of failing on the first one.

/// `config.jsonc`
struct RawConfig: Decodable {
    var view: String?
    var layout: String?
    var theme: RawThemeChoice?
    var trigger: RawTrigger?
    var launchAtLogin: Bool?
    var menuBar: OneOrMany?
    var pause: RawPause?
    var notifications: RawNotifications?
    var panels: [RawPanelRef]?
}

/// `"theme"`: a name, or one for each appearance.
enum RawThemeChoice: Decodable {
    case one(String)
    case pair(light: String?, dark: String?)

    private struct Pair: Decodable { var light: String?; var dark: String? }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let name = try? container.decode(String.self) { self = .one(name) }
        else if let pair = try? container.decode(Pair.self) { self = .pair(light: pair.light, dark: pair.dark) }
        else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: #"expected a theme name, or { "light": …, "dark": … }"#)) }
    }
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
    var doubleTapMs: Int?
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

struct RawNotifications: Decodable {
    var enabled: Bool?
    var sound: Bool?
    var quietHours: String?
    var whileOpen: Bool?
}

/// `notify`: false, true, or an object.
enum RawNotify: Decodable {
    case off
    case on(RawNotifySettings)

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let flag = try? container.decode(Bool.self) {
            self = flag ? .on(RawNotifySettings()) : .off
        } else if let settings = try? container.decode(RawNotifySettings.self) {
            self = .on(settings)
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "expected true, false or an object"))
        }
    }
}

struct RawNotifySettings: Decodable {
    var sound: Bool?
    var minInterval: String?
    var on: [String]?
}

/// An entry in `config.jsonc`'s `panels`: which panel, and optionally its size here.
struct RawPanelRef: Decodable {
    var panel: String?
    var id: String?
    var title: String?
    var size: String?
    var background: RawBackground?
    var show: Bool?
    var notify: RawNotify?
    var options: [String: RawOptionValue]?
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
    var notify: RawNotify?
    var options: [String: RawOption]?
}

/// An option's value as written: anything, so a wrong type gets a message with its path.
enum RawOptionValue: Decodable {
    case value(OptionValue)
    /// "null", "an array" or "an object".
    case other(String)

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .other("null") }
        else if let value = try? container.decode(Bool.self) { self = .value(.bool(value)) }
        else if let value = try? container.decode(Double.self) { self = .value(.number(value)) }
        else if let value = try? container.decode(String.self) { self = .value(.string(value)) }
        else if (try? container.decode([Ignored].self)) != nil { self = .other("an array") }
        else { self = .other("an object") }
    }

    private struct Ignored: Decodable { init(from decoder: any Decoder) throws {} }
}

/// One of `options` in panel.jsonc.
struct RawOption: Decodable {
    var type: String?
    var title: String?
    var description: String?
    var `default`: RawOptionValue?
    var required: Bool?
    var `enum`: [String]?
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
    var material: String?
    var font: RawThemeFont?
    var board: RawThemeBoard?
    var tile: RawThemeTile?
    var tones: [String: RawToneStyle]?
}

struct RawThemeFont: Decodable { var family: String?; var mono: String?; var scale: Double? }
struct RawThemeBoard: Decodable { var gap: Double?; var inset: Double? }
struct RawThemeTile: Decodable { var border: Double?; var shadow: Bool?; var padding: Double?; var header: RawThemeHeader? }
struct RawThemeHeader: Decodable { var uppercase: Bool?; var kind: Bool?; var interval: Bool? }
struct RawToneStyle: Decodable { var background: String? }
