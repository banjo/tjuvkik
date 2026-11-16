import Foundation
import Observation
import TjuvkikCore

/// Holds the config from `~/.config/tjuvkik/config.json`. A broken edit keeps the last good
/// config and records the errors, so the glance keeps working while you fix the file.
@MainActor
@Observable
final class ConfigStore {
    let fileURL: URL
    private(set) var config: Config
    private(set) var warnings: [ConfigIssue] = []
    private(set) var errors: [ConfigIssue] = []

    var onChange: (Config) -> Void = { _ in }

    @ObservationIgnored private var watcher: ConfigWatcher?

    init() {
        let base = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config")
        fileURL = base.appending(path: "tjuvkik/config.json")
        config = (try? ConfigLoader.parse(Data(DefaultConfig.text.utf8)).get().config)!
    }

    func start() {
        prepareDirectory()
        reload()
        watcher = ConfigWatcher(file: fileURL) { [weak self] in self?.reload() }
    }

    func reload() {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            errors = [ConfigIssue(severity: .error, path: "", message: "can't read \(fileURL.path): \(error.localizedDescription)")]
            return
        }
        switch ConfigLoader.parse(data) {
        case .success(let loaded):
            errors = []
            warnings = loaded.warnings
            if loaded.config != config {
                config = loaded.config
                onChange(config)
            }
        case .failure(let failure):
            errors = failure.issues
        }
    }

    /// Writes the default config on first run, and keeps the schema next to it up to date so
    /// `"$schema": "./config.schema.json"` gives editor completion.
    private func prepareDirectory() {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? DefaultConfig.text.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        if let schema = Bundle.main.url(forResource: "config.schema", withExtension: "json"),
           let data = try? Data(contentsOf: schema) {
            let target = directory.appending(path: "config.schema.json")
            if (try? Data(contentsOf: target)) != data { try? data.write(to: target, options: .atomic) }
        }
    }
}
