import Foundation
@testable import TjuvkikCore

/// A config directory in a temp folder, with the given files.
struct ConfigFixture {
    let directory: URL

    init(_ files: [String: String]) {
        directory = FileManager.default.temporaryDirectory.appending(path: "tjuvkik-tests/\(UUID().uuidString)")
        for (path, text) in files {
            let url = directory.appending(path: path)
            try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try! text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func load() -> Result<LoadedConfig, ConfigErrors> {
        ConfigLoader.load(from: directory)
    }

    func errors() -> [String] {
        guard case .failure(let errors) = load() else { return [] }
        return errors.issues.map(\.description)
    }
}

func load(_ files: [String: String]) throws -> LoadedConfig {
    try ConfigFixture(files).load().get()
}

func errors(_ files: [String: String]) -> [String] {
    ConfigFixture(files).errors()
}
