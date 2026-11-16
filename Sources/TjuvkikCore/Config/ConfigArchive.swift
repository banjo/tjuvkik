import Foundation

/// Exports the config directory as a zip, and imports one in its place.
public enum ConfigArchive {
    public enum Failure: Error, Equatable {
        /// The command failed, with its output.
        case command(String)
        case noConfig
        case invalid([ConfigIssue])
    }

    /// Zips everything but the generated schemas and dotfiles. Symlinks are followed, so a folder
    /// linked into a dotfiles repo exports its real files.
    public static func export(_ directory: URL, to zip: URL) throws(Failure) {
        try? FileManager.default.removeItem(at: zip)
        try run("/usr/bin/zip", ["-r", "-q", "-X", zip.path, ".", "-x", "schemas/*", "-x", ".*", "-x", "*/.*"], in: directory)
    }

    /// Replaces the directory's contents with the zip's, after checking that the zip holds a valid
    /// config and backing up the current one. Replacing contents, not the folder, keeps a stowed
    /// folder link working.
    public static func `import`(_ zip: URL, into directory: URL, backup: URL) throws(Failure) {
        let manager = FileManager.default
        let unpacked = manager.temporaryDirectory.appending(path: "tjuvkik-import-\(UUID().uuidString)")
        defer { try? manager.removeItem(at: unpacked) }
        try run("/usr/bin/unzip", ["-q", zip.path, "-d", unpacked.path], in: manager.temporaryDirectory)

        guard let root = configRoot(in: unpacked) else { throw .noConfig }
        if case .failure(let errors) = ConfigLoader.load(from: root) { throw .invalid(errors.issues) }

        do {
            try manager.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            throw .command(error.localizedDescription)
        }
        try export(directory, to: backup)

        do {
            let target = directory.resolvingSymlinksInPath()
            for item in try manager.contentsOfDirectory(atPath: target.path) {
                try manager.removeItem(at: target.appending(path: item))
            }
            for item in try manager.contentsOfDirectory(atPath: root.path) where item != "__MACOSX" {
                try manager.copyItem(at: root.appending(path: item), to: target.appending(path: item))
            }
        } catch {
            throw .command(error.localizedDescription)
        }
    }

    /// The zip's root, or its only folder when the zip was made by compressing the folder itself.
    private static func configRoot(in directory: URL) -> URL? {
        let manager = FileManager.default
        if manager.fileExists(atPath: directory.appending(path: ConfigFiles.config).path) { return directory }
        let items = ((try? manager.contentsOfDirectory(atPath: directory.path)) ?? []).filter { $0 != "__MACOSX" }
        guard items.count == 1 else { return nil }
        let nested = directory.appending(path: items[0])
        return manager.fileExists(atPath: nested.appending(path: ConfigFiles.config).path) ? nested : nil
    }

    private static func run(_ tool: String, _ arguments: [String], in directory: URL) throws(Failure) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        do {
            try process.run()
        } catch {
            throw .command(error.localizedDescription)
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw .command(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
