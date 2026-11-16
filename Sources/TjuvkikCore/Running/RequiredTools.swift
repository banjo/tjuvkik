import Foundation

public enum RequiredTools {
    /// The tools not found as executables on `path`.
    public static func missing(_ tools: [String], path: String) -> [String] {
        let directories = path.split(separator: ":").map(String.init)
        return tools.filter { tool in
            !directories.contains { FileManager.default.isExecutableFile(atPath: "\($0)/\(tool)") }
        }
    }
}
