import Foundation
import Observation
import TjuvkikCore

/// Runs each command panel on its interval in the background and keeps what it last showed.
/// A failed run keeps the last good content and records the error, so the tile goes stale
/// instead of blank.
@MainActor
@Observable
final class PanelStore {
    struct State {
        var content: ModuleContent?
        var error: String?
        var updated: Date?
        fileprivate var running = false
        fileprivate var lastRun: Date?
        fileprivate var signature = ""
    }

    private(set) var states: [String: State] = [:]
    @ObservationIgnored private var tiles: [Tile] = []
    @ObservationIgnored private var environment: [String: String]?
    @ObservationIgnored private var timer: Timer?

    func start() {
        Task {
            environment = await LoginEnvironment.load()
            refreshDue()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { self.refreshDue() }
        }
    }

    /// Takes the tiles from a new config. A panel whose command changed runs again at once.
    func update(_ tiles: [Tile]) {
        self.tiles = tiles.filter { $0.slot != nil }
        let names = Set(self.tiles.map(\.panel))
        states = states.filter { names.contains($0.key) }
        for tile in self.tiles where states[tile.panel]?.signature != Self.signature(tile) {
            states[tile.panel] = State(signature: Self.signature(tile))
        }
        refreshDue()
    }

    /// Runs every panel whose interval has passed. Called every second, and when the glance opens.
    func refreshDue() {
        guard let environment else { return }
        let now = Date()
        for tile in tiles {
            guard let command = Self.command(tile), let state = states[tile.panel], !state.running else { continue }
            if let lastRun = state.lastRun, now.timeIntervalSince(lastRun) < tile.every { continue }
            run(tile, command: command, environment: environment)
        }
    }

    private func run(_ tile: Tile, command: String, environment: [String: String]) {
        let key = tile.panel
        let signature = Self.signature(tile)
        states[key]?.running = true
        states[key]?.lastRun = Date()
        Task {
            var env = environment
            env["TJUVKIK_PANEL"] = key
            let result = await CommandRunner.run(command, in: tile.directory, environment: env, timeout: tile.timeout)
            // The config may have changed while it ran.
            guard states[key]?.signature == signature else { return }
            states[key]?.running = false
            apply(result, to: key, tile: tile)
        }
    }

    private func apply(_ result: CommandResult, to key: String, tile: Tile) {
        guard result.succeeded else {
            states[key]?.error = result.failureSummary(timeout: tile.timeout)
            return
        }
        switch tile.kind {
        case .script:
            switch ScriptOutput.parse(result.stdout) {
            case .success(let rows):
                states[key]?.content = .rows(rows)
                states[key]?.error = nil
                states[key]?.updated = Date()
            case .failure(let error):
                states[key]?.error = error.message
            }
        case .cli:
            states[key]?.content = .text(TerminalText.clean(String(decoding: result.stdout, as: UTF8.self)))
            states[key]?.error = nil
            states[key]?.updated = Date()
        case .agents:
            break
        }
    }

    private static func command(_ tile: Tile) -> String? {
        switch tile.kind {
        case .script(let command), .cli(let command): command
        case .agents: nil
        }
    }

    private static func signature(_ tile: Tile) -> String {
        "\(tile.kind)|\(tile.timeout)|\(tile.directory?.path ?? "")"
    }
}
