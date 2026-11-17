import Foundation
import Observation
import TjuvkikCore

/// Holds the config from `~/.config/tjuvkik/`. A broken edit keeps the last good config and
/// records the errors, so the glance keeps working while you fix the file.
@MainActor
@Observable
final class ConfigStore {
    let directory: URL
    private(set) var config = DefaultConfig.fallback
    private(set) var warnings: [ConfigIssue] = []
    private(set) var errors: [ConfigIssue] = []
    /// Counts reloads, so the settings window reads the file again after each.
    private(set) var revision = 0

    var onChange: (Config) -> Void = { _ in }

    @ObservationIgnored private var fingerprint = ""
    @ObservationIgnored private var poll: Timer?

    var configFile: URL {
        directory.appending(path: ConfigFiles.locate(ConfigFiles.config, in: directory) ?? "config.jsonc")
    }

    init() {
        directory = Self.defaultDirectory
    }

    /// `$XDG_CONFIG_HOME/tjuvkik`, or `~/.config/tjuvkik`.
    nonisolated static var defaultDirectory: URL {
        let base = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config")
        return base.appending(path: "tjuvkik")
    }

    func start() {
        try? DefaultConfig.write(to: directory)
        writeSchemas()
        reload()
        poll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { self.reloadIfChanged() }
        }
    }

    func reload() {
        revision += 1
        fingerprint = ConfigFingerprint.of(directory)
        switch ConfigLoader.load(from: directory) {
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

    private func reloadIfChanged() {
        if ConfigFingerprint.of(directory) != fingerprint { reload() }
    }

    /// Keeps the schemas the `$schema` keys point to up to date, for editor completion.
    private func writeSchemas() {
        guard let bundled = Bundle.main.url(forResource: "schemas", withExtension: nil),
              let names = try? FileManager.default.contentsOfDirectory(atPath: bundled.path)
        else { return }
        let target = directory.appending(path: "schemas")
        try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        for name in names {
            guard let data = try? Data(contentsOf: bundled.appending(path: name)) else { continue }
            let url = target.appending(path: name)
            if (try? Data(contentsOf: url)) != data { try? data.write(to: url, options: .atomic) }
        }
    }
}
