import Foundation

/// A `tjuvkik` command, read from the arguments.
public enum CLICommand: Equatable, Sendable {
    case help
    case version
    /// Check the config folder.
    case validate
    /// Run a tile or a panel once and say what its tile shows. `raw` prints the output as is instead.
    case run(panel: String, raw: Bool, options: [String: String] = [:])
    /// Render a tile or a panel's tile to a PNG.
    case preview(panel: String, size: TileSize?, theme: String?, output: String?, scale: Double, zoom: Double = 1, options: [String: String] = [:])
    /// Make a panel folder: `script`, `cli` or a content type.
    case new(name: String, type: String)
    /// Print a JSON schema, or list them.
    case schema(name: String?)
}

public struct CLIInvocation: Equatable, Sendable {
    public var command: CLICommand
    /// `--config`: the config folder instead of `~/.config/tjuvkik`.
    public var configDirectory: String?
}

public struct CLIUsageError: Error, Equatable, Sendable {
    public var message: String
}

public enum CLIArguments {
    public static let commands = ["validate", "run", "preview", "new", "schema", "help"]
    public static let schemas = ["config", "panel", "theme"]

    /// The arguments after the program name. Nil when they aren't a command, so the app starts:
    /// no arguments, or ones macOS passes when it launches an app (`-psn_…`, `-NS…`).
    public static func parse(_ arguments: [String]) -> Result<CLIInvocation, CLIUsageError>? {
        guard let first = arguments.first else { return nil }
        let isCommand = commands.contains(first) || ["-h", "--help", "-v", "--version", "--config"].contains(first)
        if !isCommand && first.hasPrefix("-") { return nil }
        do {
            return .success(try read(arguments))
        } catch let error as CLIUsageError {
            return .failure(error)
        } catch {
            return .failure(CLIUsageError(message: "\(error)"))
        }
    }

    private static func read(_ arguments: [String]) throws -> CLIInvocation {
        var positional: [String] = []
        var options: [String: String] = [:]
        var flags: Set<String> = []
        var given: [String: String] = [:]
        let valued = ["--config", "--size", "--theme", "--out", "-o", "--scale", "--zoom", "--type"]
        let known = ["--raw", "--cli", "--script", "-h", "--help", "-v", "--version"]
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            if argument == "--option" || argument.hasPrefix("--option=") {
                let value: String
                if argument == "--option" {
                    guard index + 1 < arguments.count else { throw CLIUsageError(message: "--option needs a value") }
                    value = arguments[index + 1]
                    index += 2
                } else {
                    value = String(argument.dropFirst("--option=".count))
                    index += 1
                }
                guard let equals = value.firstIndex(of: "="), equals != value.startIndex else {
                    throw CLIUsageError(message: "--option needs key=value, got \"\(value)\"")
                }
                let key = String(value[..<equals])
                guard given[key] == nil else { throw CLIUsageError(message: "--option \(key) is given twice") }
                given[key] = String(value[value.index(after: equals)...])
                flags.insert("--option")
                continue
            }
            if valued.contains(argument) {
                guard index + 1 < arguments.count else { throw CLIUsageError(message: "\(argument) needs a value") }
                options[argument == "-o" ? "--out" : argument] = arguments[index + 1]
                index += 2
                continue
            }
            if let equals = argument.firstIndex(of: "="), argument.hasPrefix("--"), valued.contains(String(argument[..<equals])) {
                options[String(argument[..<equals])] = String(argument[argument.index(after: equals)...])
            } else if known.contains(argument) {
                flags.insert(argument)
            } else if argument.hasPrefix("-") && argument != "-" {
                throw CLIUsageError(message: "unknown option \(argument)")
            } else {
                positional.append(argument)
            }
            index += 1
        }

        let config = options["--config"]
        if flags.contains("-h") || flags.contains("--help") { return CLIInvocation(command: .help, configDirectory: config) }
        if flags.contains("-v") || flags.contains("--version") { return CLIInvocation(command: .version, configDirectory: config) }
        guard let name = positional.first else { return CLIInvocation(command: .help, configDirectory: config) }
        let rest = Array(positional.dropFirst())

        func allow(_ allowed: [String]) throws {
            let given = Set(options.keys).subtracting(["--config"]).union(flags)
            if let extra = given.subtracting(allowed).sorted().first {
                throw CLIUsageError(message: "\(name) doesn't take \(extra)")
            }
        }
        func one(_ what: String) throws -> String {
            guard rest.count == 1 else {
                throw CLIUsageError(message: rest.isEmpty ? "\(name) needs a \(what)" : "\(name) takes one \(what), got \(rest.count)")
            }
            return rest[0]
        }

        let command: CLICommand
        switch name {
        case "help":
            try allow([])
            command = .help
        case "validate":
            try allow([])
            guard rest.isEmpty else { throw CLIUsageError(message: "validate takes no arguments") }
            command = .validate
        case "run":
            try allow(["--raw", "--option"])
            command = .run(panel: try one("panel name"), raw: flags.contains("--raw"), options: given)
        case "preview":
            try allow(["--size", "--theme", "--out", "--scale", "--zoom", "--option"])
            var size: TileSize?
            if let value = options["--size"] {
                size = TileSize(rawValue: value)
                if size == nil { throw CLIUsageError(message: "unknown size \"\(value)\", expected s, m, l or xl") }
            }
            var scale = 2.0
            if let value = options["--scale"] {
                guard let parsed = Double(value), (1...4).contains(parsed) else {
                    throw CLIUsageError(message: "--scale must be a number from 1 to 4, got \"\(value)\"")
                }
                scale = parsed
            }
            var zoom = 1.0
            if let value = options["--zoom"] {
                guard let parsed = Double(value), Config.Zoom.range.contains(parsed) else {
                    throw CLIUsageError(message: "--zoom must be a number from \(Config.Zoom.range.lowerBound.formatted()) to \(Config.Zoom.range.upperBound.formatted()), got \"\(value)\"")
                }
                zoom = parsed
            }
            command = .preview(panel: try one("panel name"), size: size, theme: options["--theme"], output: options["--out"], scale: scale, zoom: zoom, options: given)
        case "new":
            try allow(["--type", "--cli", "--script"])
            let choices = [options["--type"], flags.contains("--cli") ? "cli" : nil, flags.contains("--script") ? "script" : nil].compactMap { $0 }
            guard choices.count <= 1 else { throw CLIUsageError(message: "pick one of --type, --cli and --script") }
            let type = choices.first ?? "script"
            guard PanelTemplate.types.contains(type) else {
                throw CLIUsageError(message: "unknown type \"\(type)\", expected one of \(PanelTemplate.types.joined(separator: ", "))")
            }
            let panel = try one("panel name")
            guard PanelTemplate.isValidName(panel) else {
                throw CLIUsageError(message: "\"\(panel)\" can't be a panel name: use letters, digits, - and _")
            }
            command = .new(name: panel, type: type)
        case "schema":
            try allow([])
            guard rest.count <= 1 else { throw CLIUsageError(message: "schema takes at most one name") }
            if let schema = rest.first, !schemas.contains(schema) {
                throw CLIUsageError(message: "unknown schema \"\(schema)\", expected \(schemas.joined(separator: ", "))")
            }
            command = .schema(name: rest.first)
        default:
            throw CLIUsageError(message: "unknown command \"\(name)\"")
        }
        return CLIInvocation(command: command, configDirectory: config)
    }

    public static let usage = """
    Usage: tjuvkik <command> [options]

    Commands:
      validate                 Check the config folder: config.jsonc, every panel and theme.
      run <tile|panel>         Run a panel once, as the app does, and say what its tile shows.
                               A tile's id uses its options from config.jsonc; a panel's name uses its defaults.
          --raw                Print the command's output as is.
          --option key=value   Set an option. Repeat for more.
      preview <tile|panel>     Run a panel and render its tile to a PNG.
          --option key=value   Set an option. Repeat for more.
          --size s|m|l|xl      The tile's size. Default: the panel's size.
          --theme <name>       Default: the theme in config.jsonc for the current appearance.
          -o, --out <file>     Default: <panel>-<size>.png in this folder.
          --scale <1-4>        Pixels per point. Default: 2.
          --zoom <0.75-2>      Draw the tile as the glance does at this zoom. Default: 1.
      new <name>               Make panels/<name>/ with a panel.jsonc and a script.
          --type <type>        script (default), cli, or a content type like stats or table.
      schema [config|panel|theme]
                               Print a JSON schema, or list them.
      help                     Show this.

    Options:
      --config <folder>        The config folder. Default: $XDG_CONFIG_HOME/tjuvkik or ~/.config/tjuvkik.
      -v, --version            Print the version.

    Run without a command to start the app.
    """
}
