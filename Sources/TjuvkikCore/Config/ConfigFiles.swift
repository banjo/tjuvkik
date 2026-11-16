import Foundation

/// Reads and decodes one file of the config directory, collecting issues against its path.
public struct ConfigFiles {
    let directory: URL
    var issues: [ConfigIssue] = []

    // Files are named without their extension: `.jsonc` (preferred, editors allow comments in it)
    // or `.json`.
    public static let config = "config"
    public static func panel(_ name: String) -> String { "panels/\(name)/panel" }
    public static func theme(_ name: String) -> String { "themes/\(name)" }
    public static let extensions = ["jsonc", "json"]

    /// The file for a name: `.jsonc` if it exists, else `.json` if it exists, else nil.
    public static func locate(_ name: String, in directory: URL) -> String? {
        extensions.map { "\(name).\($0)" }.first {
            FileManager.default.fileExists(atPath: directory.appending(path: $0).path)
        }
    }

    /// The file for a name, warning when both extensions exist. Names a `.jsonc` when neither does.
    mutating func locate(_ name: String) -> String {
        let found = Self.extensions.map { "\(name).\($0)" }.filter {
            FileManager.default.fileExists(atPath: directory.appending(path: $0).path)
        }
        if found.count > 1 { warning(found[1], "", "ignored, because \(found[0]) exists") }
        return found.first ?? "\(name).jsonc"
    }

    func exists(_ name: String) -> Bool {
        Self.locate(name, in: directory) != nil
    }

    mutating func error(_ file: String, _ path: String = "", _ message: String) {
        issues.append(ConfigIssue(severity: .error, file: file, path: path, message: message))
    }

    mutating func warning(_ file: String, _ path: String = "", _ message: String) {
        issues.append(ConfigIssue(severity: .warning, file: file, path: path, message: message))
    }

    /// Decodes JSON with comments and trailing commas (JSON5). Nil if missing or broken.
    mutating func read<T: Decodable>(_ type: T.Type, from file: String) -> T? {
        let data: Data
        do {
            data = try Data(contentsOf: directory.appending(path: file))
        } catch {
            self.error(file, "", "can't read the file")
            return nil
        }
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            let (path, message) = Self.describe(error)
            self.error(file, path, message)
        } catch {
            self.error(file, "", error.localizedDescription)
        }
        return nil
    }

    /// Names of `themes/*.jsonc` and `themes/*.json`.
    func themeNames() -> [String] {
        let themes = directory.appending(path: "themes")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: themes.path)) ?? []
        let names = files.compactMap { file in
            Self.extensions.first { file.hasSuffix(".\($0)") }.map { String(file.dropLast($0.count + 1)) }
        }
        return Set(names).sorted()
    }

    private static func describe(_ error: DecodingError) -> (path: String, message: String) {
        func path(_ codingPath: [any CodingKey]) -> String {
            codingPath.reduce("") { result, key in
                if let index = key.intValue { return "\(result)[\(index)]" }
                return result.isEmpty ? key.stringValue : "\(result).\(key.stringValue)"
            }
        }
        switch error {
        case .typeMismatch(let type, let context):
            return (path(context.codingPath), "expected \(typeName(type))")
        case .valueNotFound(let type, let context):
            return (path(context.codingPath), "expected \(typeName(type)), got null")
        case .keyNotFound(let key, let context):
            return (path(context.codingPath), "missing \"\(key.stringValue)\"")
        case .dataCorrupted(let context):
            let underlying = (context.underlyingError as NSError?)?.userInfo[NSDebugDescriptionErrorKey] as? String
            return (path(context.codingPath), underlying ?? context.debugDescription)
        @unknown default:
            return ("", error.localizedDescription)
        }
    }

    private static func typeName(_ type: Any.Type) -> String {
        switch type {
        case is String.Type: "a string"
        case is Bool.Type: "true or false"
        case is Int.Type, is Double.Type: "a number"
        case is [RawPanelRef].Type: "a list of panels"
        default: "an object"
        }
    }
}
