import Foundation

/// An option's value, from config.jsonc, a default or `--option`.
public enum OptionValue: Equatable, Sendable, Encodable {
    case string(String)
    case number(Double)
    case bool(Bool)

    /// As an environment variable: `10`, `2.5`, `true`, the string as is.
    public var text: String {
        switch self {
        case .string(let value): value
        case .bool(let value): value ? "true" : "false"
        case .number(let value): value == value.rounded() && abs(value) < 1e15 ? String(Int(value)) : String(value)
        }
    }

    /// In a message: a string in quotes, the rest as is.
    var shown: String {
        if case .string(let value) = self { return "\"\(value)\"" }
        return text
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .number(let value):
            if value == value.rounded() && abs(value) < 1e15 { try container.encode(Int(value)) } else { try container.encode(value) }
        }
    }
}

/// An option a panel declares in its `options`.
public struct PanelOption: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable { case string, number, boolean }

    public var name: String
    public var kind: Kind
    /// A label for forms. Nil: use the name.
    public var title: String?
    public var description: String?
    public var defaultValue: OptionValue?
    public var required: Bool
    /// The allowed values of a string option.
    public var choices: [String]?

    public init(name: String, kind: Kind, title: String? = nil, description: String? = nil, defaultValue: OptionValue? = nil, required: Bool = false, choices: [String]? = nil) {
        self.name = name
        self.kind = kind
        self.title = title
        self.description = description
        self.defaultValue = defaultValue
        self.required = required
        self.choices = choices
    }

    /// `TJUVKIK_OPTION_REPO` for `repo`, `TJUVKIK_OPTION_MY_REPO` for `my-repo`.
    public var variable: String { "TJUVKIK_OPTION_" + name.uppercased().replacingOccurrences(of: "-", with: "_") }
}

/// Checks the options a panel declares and the values a tile gives them, and hands them to the
/// command as environment variables.
public enum PanelOptions {
    /// panel.jsonc's `options`, checked. Errors and warnings go to `file`, under `options`.
    static func declarations(_ raw: [String: RawOption]?, file: String, files: inout ConfigFiles) -> [PanelOption] {
        var options: [PanelOption] = []
        var variables: [String: String] = [:]
        for name in (raw ?? [:]).keys.sorted() {
            let rawOption = raw![name]!
            let path = "options.\(name)"
            guard isValidName(name) else {
                files.error(file, "options", "\"\(name)\" isn't an option name: start with a letter, then use letters, digits, - and _")
                continue
            }
            let types = #"expected "string", "number" or "boolean""#
            guard let type = rawOption.type else {
                files.error(file, "\(path).type", "missing \"type\", \(types)")
                continue
            }
            guard let kind = PanelOption.Kind(rawValue: type) else {
                files.error(file, "\(path).type", "unknown type \"\(type)\", \(types)")
                continue
            }
            var option = PanelOption(name: name, kind: kind, title: rawOption.title, description: rawOption.description, required: rawOption.required ?? false)
            if let choices = rawOption.enum {
                if kind != .string {
                    files.error(file, "\(path).enum", "only a string option can have enum")
                } else if choices.isEmpty {
                    files.error(file, "\(path).enum", "can't be empty")
                } else {
                    option.choices = choices
                }
            }
            if let raw = rawOption.default {
                switch check(raw, kind).flatMap({ allowed($0, option.choices) }) {
                case .success(let value): option.defaultValue = value
                case .failure(let error): files.error(file, "\(path).default", error.message)
                }
                if option.required { files.warning(file, "\(path).required", "it has a default, so it's never missing") }
            }
            if let earlier = variables[option.variable] {
                files.error(file, path, "\"\(earlier)\" already uses \(option.variable)")
                continue
            }
            variables[option.variable] = name
            options.append(option)
        }
        return options
    }

    /// A tile's values against the declarations, with the defaults filled in. `required`: false
    /// when the panel is checked on its own, without a tile.
    static func resolve(_ given: [String: RawOptionValue]?, declared: [PanelOption], panel: String, required: Bool, file: String, path: String, files: inout ConfigFiles) -> [String: OptionValue] {
        let base = path.isEmpty ? "options" : "\(path).options"
        let given = given ?? [:]
        for name in given.keys.sorted() where !declared.contains(where: { $0.name == name }) {
            files.error(file, "\(base).\(name)", unknown(name, panel: panel, declared: declared))
        }
        var values: [String: OptionValue] = [:]
        for option in declared {
            if let raw = given[option.name] {
                switch check(raw, option.kind).flatMap({ allowed($0, option.choices) }) {
                case .success(let value): values[option.name] = value
                case .failure(let error): files.error(file, "\(base).\(option.name)", error.message)
                }
                continue
            }
            if let value = option.defaultValue {
                values[option.name] = value
            } else if required, option.required {
                files.error(file, base, "missing \"\(option.name)\", which \"\(panel)\" requires")
            }
        }
        return values
    }

    /// A `--option` value, read as the option's type.
    public static func parse(_ text: String, as option: PanelOption) -> Result<OptionValue, OptionError> {
        switch option.kind {
        case .string:
            allowed(.string(text), option.choices)
        case .number:
            Double(text).map { .success(.number($0)) } ?? .failure(OptionError("expected a number, got \"\(text)\""))
        case .boolean:
            switch text {
            case "true": .success(.bool(true))
            case "false": .success(.bool(false))
            default: .failure(OptionError("expected true or false, got \"\(text)\""))
            }
        }
    }

    /// What a tile's command gets: the base environment without other tiles' options, plus
    /// TJUVKIK_PANEL, TJUVKIK_ID, one TJUVKIK_OPTION_<NAME> per value and TJUVKIK_OPTIONS.
    public static func environment(_ base: [String: String], for tile: Tile) -> [String: String] {
        var environment = base.filter { !$0.key.hasPrefix("TJUVKIK_OPTION_") && $0.key != "TJUVKIK_OPTIONS" }
        environment["TJUVKIK_PANEL"] = tile.panel
        environment["TJUVKIK_ID"] = tile.id
        for option in tile.declaredOptions {
            if let value = tile.options[option.name] { environment[option.variable] = value.text }
        }
        environment["TJUVKIK_OPTIONS"] = json(tile.options)
        return environment
    }

    /// `{"limit":10,"repo":"banjo/tjuvkik"}`: sorted keys, no spaces.
    public static func json(_ values: [String: OptionValue]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(values)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    /// `"nope"` given to a panel that doesn't declare it.
    static func unknown(_ name: String, panel: String, declared: [PanelOption]) -> String {
        guard !declared.isEmpty else { return "\"\(panel)\" has no options" }
        return "\"\(panel)\" has no option \"\(name)\", expected one of \(declared.map { "\"\($0.name)\"" }.sorted().joined(separator: ", "))"
    }

    private static func isValidName(_ name: String) -> Bool {
        guard let first = name.first, first.isASCII, first.isLetter else { return false }
        return name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }

    private static func check(_ value: RawOptionValue, _ kind: PanelOption.Kind) -> Result<OptionValue, OptionError> {
        let got: String
        switch value {
        case .value(let value):
            switch (kind, value) {
            case (.string, .string), (.number, .number), (.boolean, .bool): return .success(value)
            default: got = value.shown
            }
        case .other(let text):
            got = text
        }
        return switch kind {
        case .string: .failure(OptionError("expected a string, got \(got)"))
        case .number: .failure(OptionError("expected a number, got \(got)"))
        case .boolean: .failure(OptionError("expected true or false, got \(got)"))
        }
    }

    private static func allowed(_ value: OptionValue, _ choices: [String]?) -> Result<OptionValue, OptionError> {
        guard let choices, case .string(let text) = value, !choices.contains(text) else { return .success(value) }
        return .failure(OptionError("\(value.shown) isn't one of \(choices.map { "\"\($0)\"" }.joined(separator: ", "))"))
    }
}

/// Why an option's value isn't accepted.
public struct OptionError: Error, Equatable, Sendable {
    public var message: String
    init(_ message: String) { self.message = message }
}
