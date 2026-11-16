import Foundation
import Observation
import TjuvkikCore

/// Runs each panel's command in the background and keeps what it last showed. Interval panels
/// run on their interval; stream panels keep running and are restarted when they exit. A failed
/// run keeps the last good content and records the error, so the tile goes stale instead of blank.
@MainActor
@Observable
final class PanelStore {
    struct State {
        var content: ModuleContent?
        var error: String?
        var updated: Date?
        fileprivate var signature = ""
        fileprivate var running = false
        fileprivate var lastRun: Date?
        fileprivate var stream: CommandStream?
        fileprivate var streamStarted: Date?
        fileprivate var restartDelay: Double = 1
        fileprivate var restartAt: Date?
        /// A cli stream's latest lines.
        fileprivate var lines: [String] = []
    }

    /// How many lines a cli stream keeps.
    private static let streamLines = 300

    private(set) var states: [String: State] = [:]
    @ObservationIgnored private var tiles: [Tile] = []
    @ObservationIgnored private var environment: [String: String]?
    @ObservationIgnored private var timer: Timer?

    func start() {
        Task {
            environment = await LoginEnvironment.load()
            checkRequirements()
            refreshDue()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { self.refreshDue() }
        }
    }

    func stopAll() {
        for state in states.values { state.stream?.stop() }
    }

    /// Takes the tiles from a new config. A panel whose command changed starts over.
    func update(_ tiles: [Tile]) {
        self.tiles = tiles.filter { $0.slot != nil }
        let names = Set(self.tiles.map(\.panel))
        for (name, state) in states where !names.contains(name) {
            state.stream?.stop()
            states[name] = nil
        }
        for tile in self.tiles where states[tile.panel]?.signature != Self.signature(tile) {
            states[tile.panel]?.stream?.stop()
            states[tile.panel] = State(signature: Self.signature(tile))
        }
        checkRequirements()
        refreshDue()
    }

    /// Starts what's due: interval panels whose interval has passed, and stream panels that
    /// aren't running. Called every second, and when the glance opens.
    func refreshDue() {
        guard let environment else { return }
        let now = Date()
        for tile in tiles {
            guard let state = states[tile.panel], !state.running, !isBlocked(tile) else { continue }
            switch tile.mode {
            case .interval:
                if let lastRun = state.lastRun, now.timeIntervalSince(lastRun) < tile.every { continue }
                run(tile, environment: environment)
            case .stream:
                if let restartAt = state.restartAt, now < restartAt { continue }
                stream(tile, environment: environment)
            }
        }
    }

    // MARK: Requirements

    @ObservationIgnored private var missing: [String: [String]] = [:]

    private func isBlocked(_ tile: Tile) -> Bool {
        !(missing[tile.panel] ?? []).isEmpty
    }

    /// A panel that needs a tool you don't have says so instead of failing on every run.
    private func checkRequirements() {
        guard let path = environment?["PATH"] else { return }
        for tile in tiles {
            let tools = RequiredTools.missing(tile.requires, path: path)
            missing[tile.panel] = tools
            if !tools.isEmpty {
                states[tile.panel]?.error = "needs \(tools.joined(separator: ", ")), not found on PATH"
            } else if states[tile.panel]?.error?.hasPrefix("needs ") == true {
                states[tile.panel]?.error = nil
            }
        }
    }

    // MARK: Interval panels

    private func run(_ tile: Tile, environment: [String: String]) {
        let key = tile.panel
        let signature = Self.signature(tile)
        states[key]?.running = true
        states[key]?.lastRun = Date()
        Task {
            let result = await CommandRunner.run(tile.command, in: tile.directory, environment: Self.environment(environment, tile), timeout: tile.timeout)
            // The config may have changed while it ran.
            guard states[key]?.signature == signature else { return }
            states[key]?.running = false
            guard result.succeeded else {
                states[key]?.error = result.failureSummary(timeout: tile.timeout)
                return
            }
            show(String(decoding: result.stdout, as: UTF8.self), in: key, kind: tile.kind)
        }
    }

    // MARK: Stream panels

    private func stream(_ tile: Tile, environment: [String: String]) {
        let key = tile.panel
        let signature = Self.signature(tile)
        states[key]?.running = true
        states[key]?.streamStarted = Date()
        states[key]?.restartAt = nil
        states[key]?.stream = CommandStream(
            tile.command, in: tile.directory, environment: Self.environment(environment, tile),
            onLine: { line in
                Task { @MainActor [weak self] in
                    guard let self, self.states[key]?.signature == signature else { return }
                    self.receive(line, in: key, kind: tile.kind)
                }
            },
            onExit: { exit in
                Task { @MainActor [weak self] in
                    guard let self, self.states[key]?.signature == signature, !exit.stopped else { return }
                    self.streamExited(key, exit: exit)
                }
            }
        )
    }

    private func receive(_ line: String, in key: String, kind: Tile.Kind) {
        switch kind {
        case .script:
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            show(line, in: key, kind: kind)
        case .cli:
            var lines = states[key]?.lines ?? []
            lines.append(TerminalText.clean(line))
            if lines.count > Self.streamLines { lines.removeFirst(lines.count - Self.streamLines) }
            states[key]?.lines = lines
            states[key]?.content = .tail(lines.joined(separator: "\n"))
            states[key]?.error = nil
            states[key]?.updated = Date()
        }
    }

    /// Restarts after a growing delay, from 1s up to 30s; one that ran a while starts over at 1s.
    private func streamExited(_ key: String, exit: CommandStream.Exit) {
        guard var state = states[key] else { return }
        let ranFor = state.streamStarted.map { Date().timeIntervalSince($0) } ?? 0
        state.restartDelay = ranFor > 30 ? 1 : min(state.restartDelay * 2, 30)
        state.restartAt = Date().addingTimeInterval(state.restartDelay)
        state.running = false
        state.stream = nil
        state.error = exit.summary
        states[key] = state
    }

    // MARK: Actions

    /// Runs a row's command, like the menu's. A failure shows on the panel's tile until it next
    /// updates.
    func runAction(_ command: String, panel: String) {
        guard let environment, let tile = tiles.first(where: { $0.panel == panel }) else { return }
        Task {
            let result = await CommandRunner.launch(command, in: tile.directory, environment: Self.environment(environment, tile))
            if !result.succeeded {
                states[panel]?.error = "\(command): \(result.failureSummary(timeout: 30))"
            }
        }
    }

    // MARK: Shared

    private func show(_ output: String, in key: String, kind: Tile.Kind) {
        switch kind {
        case .script:
            switch ScriptOutput.parse(Data(output.utf8)) {
            case .success(let rows):
                states[key]?.content = .rows(rows)
                states[key]?.error = nil
                states[key]?.updated = Date()
            case .failure(let error):
                states[key]?.error = error.message
            }
        case .cli:
            states[key]?.content = .text(TerminalText.clean(output))
            states[key]?.error = nil
            states[key]?.updated = Date()
        }
    }

    private static func environment(_ base: [String: String], _ tile: Tile) -> [String: String] {
        var environment = base
        environment["TJUVKIK_PANEL"] = tile.panel
        return environment
    }

    private static func signature(_ tile: Tile) -> String {
        "\(tile.kind)|\(tile.mode)|\(tile.command)|\(tile.timeout)|\(tile.directory.path)"
    }
}
