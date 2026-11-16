import Foundation

/// Reads and decodes one file of the config directory, collecting issues against its path.
struct ConfigFiles {
    let directory: URL
    var issues: [ConfigIssue] = []

    static let config = "config.json"
    static func panel(_ name: String) -> String { "panels/\(name)/panel.json" }
    static func theme(_ name: String) -> String { "themes/\(name).json" }

    func exists(_ file: String) -> Bool {
        FileManager.default.fileExists(atPath: directory.appending(path: file).path)
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

    /// Names of `themes/*.json`.
    func themeNames() -> [String] {
        let themes = directory.appending(path: "themes")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: themes.path)) ?? []
        return files.filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) }.sorted()
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
