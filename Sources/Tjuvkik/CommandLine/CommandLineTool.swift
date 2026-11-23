import AppKit
import SwiftUI
import TjuvkikCore

/// `tjuvkik <command>`: the same binary as the app, run from a terminal. See `CLIArguments`.
@MainActor
enum CommandLineTool {
    enum Exit: Int32 {
        case ok = 0
        case failed = 1
        case usage = 2
    }

    /// Runs the command and exits, or returns when the arguments mean "start the app".
    static func runIfCommand(_ arguments: [String]) {
        guard let parsed = CLIArguments.parse(Array(arguments.dropFirst())) else { return }
        switch parsed {
        case .failure(let error):
            printError("\(error.message)\nRun `tjuvkik help` for the commands.")
            exit(Exit.usage.rawValue)
        case .success(let invocation):
            // So lines and errors keep their order when piped.
            setvbuf(stdout, nil, _IOLBF, 0)
            let directory = invocation.configDirectory.map {
                URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath).standardizedFileURL
            } ?? ConfigStore.defaultDirectory
            Task { @MainActor in
                let code = await run(invocation.command, directory: directory)
                exit(code.rawValue)
            }
            // Keeps the main thread serving the task (and the main actor) until it exits.
            RunLoop.main.run()
            exit(Exit.failed.rawValue)
        }
    }

    private static func run(_ command: CLICommand, directory: URL) async -> Exit {
        switch command {
        case .help:
            print(CLIArguments.usage)
            return .ok
        case .version:
            print(app.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")
            return .ok
        case .validate:
            let validation = ConfigValidation.check(directory)
            print(validation.report)
            return validation.isValid ? .ok : .failed
        case .run(let panel, let raw, let options):
            return await runPanel(panel, raw: raw, options: options, directory: directory)
        case .preview(let panel, let size, let theme, let output, let scale, let zoom, let options):
            return await preview(panel, size: size, themeName: theme, output: output, scale: scale, zoom: zoom, options: options, directory: directory)
        case .new(let name, let type):
            return makePanel(name, type: type, directory: directory)
        case .schema(let name):
            return schema(name, directory: directory)
        }
    }

    // MARK: run

    private static func runPanel(_ name: String, raw: Bool, options: [String: String], directory: URL) async -> Exit {
        guard let tile = loadPanel(name, options: options, directory: directory) else { return .failed }
        guard let environment = await environment(for: tile) else { return .failed }

        if tile.mode == .stream {
            if !raw { print("\(name): \(tile.typeName), streaming. Ctrl-C stops it.") }
            let ended = await stream(tile, environment: environment) { line in
                if raw {
                    print(line)
                } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    describe(PanelOutput.content(Data(line.utf8), for: tile))
                }
                return true
            }
            // Ctrl-C is the way out; the command ending on its own is a failure, as in the app.
            guard let ended else { return .ok }
            printError("\(name): \(ended)")
            return .failed
        }

        let started = Date()
        let result = await once(tile, environment: environment)
        let seconds = Date().timeIntervalSince(started)
        switch result {
        case .failure(let failure):
            printError("\(name): \(failure.message)")
            return .failed
        case .success(let output):
            if raw {
                FileHandle.standardOutput.write(output)
                return .ok
            }
            let source = tile.file.map { "read \(($0.path as NSString).abbreviatingWithTildeInPath)" }
                ?? "ran in \(String(format: "%.2f", seconds))s"
            print("\(name): \(tile.typeName), \(source)")
            return describe(PanelOutput.content(output, for: tile)) ? .ok : .failed
        }
    }

    /// Prints what the tile shows, or why it can't. False on an error.
    @discardableResult
    private static func describe(_ content: Result<ModuleContent, ScriptOutputError>) -> Bool {
        switch content {
        case .success(let content):
            print("  shows \(content.outline)")
            if let menuBar = content.menuBar, !menuBar.title.isEmpty {
                print("  menu bar: \(menuBar.title)")
            }
            // Warnings, not errors: the tile still shows, just without the icon.
            for problem in iconProblems(content.icons) { printError("  \(problem)") }
            return true
        case .failure(let error):
            printError("  \(error.message)")
            return false
        }
    }

    /// Unknown effects and symbols this Mac doesn't have, once each.
    private static func iconProblems(_ icons: [String]) -> [String] {
        var seen = Set<String>()
        return icons.filter { seen.insert($0).inserted }.compactMap { raw in
            if let problem = Icon.problem(raw) { return problem }
            if case .symbol(let name, _) = Icon(raw), NSImage(systemSymbolName: name, accessibilityDescription: nil) == nil {
                return "icon \"\(raw)\": no SF Symbol named \"\(name)\""
            }
            return nil
        }
    }

    // MARK: preview

    private static func preview(_ panel: String, size: TileSize?, themeName: String?, output: String?, scale: Double, zoom: Double, options: [String: String], directory: URL) async -> Exit {
        guard var tile = loadPanel(panel, options: options, directory: directory) else { return .failed }
        let config = try? ConfigLoader.load(from: directory).get().config
        // No NSApplication runs here, so no effectiveAppearance.
        let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        let name = themeName ?? config?.themeName(dark: isDark) ?? "dark-glass"
        let theme: Theme
        switch ConfigLoader.theme(name, in: directory) {
        case .success(let resolved): theme = resolved.zoomed(zoom)
        case .failure(let failure):
            failure.issues.forEach { printError("\($0)") }
            return .failed
        }
        if let size { tile.size = size }
        guard let environment = await environment(for: tile) else { return .failed }

        var state: PanelStore.State
        var exit = Exit.ok
        let result: Result<Data, Failure>
        if tile.mode == .stream {
            result = await firstLine(of: tile, environment: environment)
        } else {
            result = await once(tile, environment: environment)
        }
        switch result.flatMap({ output in PanelOutput.content(output, for: tile).mapError { Failure(message: $0.message) } }) {
        case .success(let content):
            state = PanelStore.State(content: ChartHistory.apply(to: content, kept: [], limit: tile.history).content, error: nil)
        case .failure(let failure):
            printError("\(panel): \(failure.message)")
            state = PanelStore.State(content: nil, error: failure.message)
            exit = .failed
        }

        let url = URL(fileURLWithPath: output ?? "\(panel)-\(tile.size.rawValue).png")
        do {
            try render(tile: tile, state: state, theme: theme, scale: scale, to: url)
        } catch {
            printError("can't write \(url.path): \(error.localizedDescription)")
            return .failed
        }
        let points = tileSize(tile.size, theme: theme)
        print("\(url.path): \(tile.size.rawValue), \(Int(points.width))×\(Int(points.height)) pt at \(scale.formatted())x\(zoom == 1 ? "" : ", zoom \(zoom.formatted())"), \(name)")
        return exit
    }

    /// A tile of `size` at the theme's zoom.
    private static func tileSize(_ size: TileSize, theme: Theme) -> CGSize {
        let cell = CGSize(width: theme.z(BentoGeometry.cell.width), height: theme.z(BentoGeometry.cell.height))
        return BentoGeometry.size(columns: size.columns, rows: size.rows, cell: cell, board: theme.board)
    }

    /// The tile at its size and zoom, with room around it for its shadow.
    private static func render(tile: Tile, state: PanelStore.State, theme: Theme, scale: Double, to url: URL) throws {
        let size = tileSize(tile.size, theme: theme)
        let margin = theme.z(24)
        let view = TileView(tile: tile, state: state, theme: theme, index: 0, isVisible: true, solid: true)
            .frame(width: size.width, height: size.height)
            .padding(margin)
            .environment(\.colorScheme, theme.appearance.colorScheme)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: url, options: .atomic)
    }

    // MARK: new

    private static func makePanel(_ name: String, type: String, directory: URL) -> Exit {
        let folder = directory.appending(path: "panels/\(name)")
        if FileManager.default.fileExists(atPath: folder.path) {
            printError("\(abbreviate(folder)) already exists")
            return .failed
        }
        do {
            for file in PanelTemplate.files(name: name, type: type) {
                let url = directory.appending(path: file.path)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try file.text.write(to: url, atomically: true, encoding: .utf8)
                if file.executable {
                    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
                }
                print("created \(abbreviate(url))")
            }
        } catch {
            printError("can't create the panel: \(error.localizedDescription)")
            return .failed
        }
        print("""

        Next:
          tjuvkik run \(name)        see what it shows
          tjuvkik preview \(name)    render its tile
        Then add { "panel": "\(name)" } to "panels" in \(abbreviate(directory.appending(path: "config.jsonc"))).
        """)
        return .ok
    }

    // MARK: schema

    private static func schema(_ name: String?, directory: URL) -> Exit {
        // The app's own, or the copies it keeps in the config folder when run outside the app.
        let copies = directory.appending(path: "schemas")
        guard let folder = app.url(forResource: "schemas", withExtension: nil)
            ?? (FileManager.default.fileExists(atPath: copies.path) ? copies : nil)
        else {
            printError("no schemas: they ship in Tjuvkik.app, so run tjuvkik from the installed app")
            return .failed
        }
        guard let name else {
            for schema in CLIArguments.schemas {
                print("\(schema)\t\(folder.appending(path: "\(schema).schema.json").path)")
            }
            return .ok
        }
        guard let data = try? Data(contentsOf: folder.appending(path: "\(name).schema.json")) else {
            printError("no \(name).schema.json in \(folder.path)")
            return .failed
        }
        FileHandle.standardOutput.write(data)
        return .ok
    }

    /// Tjuvkik.app, also when run through a link like `~/.local/bin/tjuvkik`, which
    /// `Bundle.main` takes for a lone binary.
    private static var app: Bundle {
        let executable = (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])).resolvingSymlinksInPath()
        let bundle = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard bundle.pathExtension == "app", let app = Bundle(url: bundle) else { return Bundle.main }
        return app
    }

    // MARK: Running a panel

    private static func loadPanel(_ name: String, options: [String: String], directory: URL) -> Tile? {
        switch ConfigLoader.runnable(name, options: options, in: directory) {
        case .success(let tile):
            return tile
        case .failure(let failure):
            failure.issues.forEach { printError("error: \($0)") }
            if !ConfigLoader.panelNames(in: directory).isEmpty, ConfigFiles.locate(ConfigFiles.panel(name), in: directory) == nil {
                printError("panels: \(ConfigLoader.panelNames(in: directory).joined(separator: ", "))")
            }
            return nil
        }
    }

    /// The login shell's environment, as the app runs commands with. Nil when a required tool is
    /// missing, after saying so.
    private static func environment(for tile: Tile) async -> [String: String]? {
        var environment = PanelOptions.environment(await LoginEnvironment.load(), for: tile)
        environment["TJUVKIK_RUN"] = "cli"
        let missing = RequiredTools.missing(tile.requires, path: environment["PATH"] ?? "")
        guard missing.isEmpty else {
            printError("\(tile.panel): needs \(missing.joined(separator: ", ")), not found on PATH")
            return nil
        }
        return environment
    }

    /// An interval panel's run, or a file panel's file.
    private static func once(_ tile: Tile, environment: [String: String]) async -> Result<Data, Failure> {
        if let file = tile.file {
            guard let data = FileManager.default.contents(atPath: file.path) else {
                return .failure(Failure(message: "can't read \(abbreviate(file))"))
            }
            // A file is markdown as is, not JSON.
            let json = try? JSONEncoder().encode(["markdown": String(decoding: data, as: UTF8.self)])
            return json.map { .success($0) } ?? .failure(Failure(message: "can't read \(abbreviate(file))"))
        }
        let result = await CommandRunner.run(tile.command, in: tile.directory, environment: environment, timeout: tile.timeout)
        if !result.stderr.isEmpty { FileHandle.standardError.write(Data(result.stderr.utf8)) }
        guard result.succeeded else { return .failure(Failure(message: result.failureSummary(timeout: tile.timeout))) }
        return .success(result.stdout)
    }

    /// A stream panel's first document, waiting up to its timeout.
    private static func firstLine(of tile: Tile, environment: [String: String]) async -> Result<Data, Failure> {
        var first: String?
        let finished = await stream(tile, environment: environment, timeout: max(tile.timeout, 10)) { line in
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
            first = line
            return false
        }
        if let first { return .success(Data(first.utf8)) }
        return .failure(Failure(message: finished ?? "printed nothing within \(Int(max(tile.timeout, 10)))s"))
    }

    /// Runs a stream panel and hands over each line until `onLine` returns false, the command
    /// exits, the timeout passes or Ctrl-C. Returns why it ended when the command did.
    @discardableResult
    private static func stream(_ tile: Tile, environment: [String: String], timeout: Double? = nil, onLine: @escaping @MainActor (String) -> Bool) async -> String? {
        await withCheckedContinuation { continuation in
            let session = StreamSession(continuation)
            signal(SIGINT, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
            source.setEventHandler { MainActor.assumeIsolated { session.finish(nil) } }
            source.resume()
            session.interrupt = source
            session.stream = CommandStream(
                tile.command, in: tile.directory, environment: environment,
                onLine: { line in
                    Task { @MainActor in
                        guard !session.done else { return }
                        if !onLine(line) { session.finish(nil) }
                    }
                },
                onExit: { exit in
                    Task { @MainActor in session.finish(exit.stopped ? nil : exit.summary) }
                }
            )
            if let timeout {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(timeout))
                    session.finish(nil)
                }
            }
        }
    }

    // MARK: Output

    private static func printError(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    private static func abbreviate(_ url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }
}

/// Why a panel's run gave nothing to show.
private struct Failure: Error {
    var message: String
}

/// One run of a stream panel, ended once: by its command, a timeout or Ctrl-C.
@MainActor
private final class StreamSession: Sendable {
    private let continuation: CheckedContinuation<String?, Never>
    private(set) var done = false
    var stream: CommandStream?
    var interrupt: (any DispatchSourceSignal)?

    init(_ continuation: CheckedContinuation<String?, Never>) {
        self.continuation = continuation
    }

    func finish(_ reason: String?) {
        guard !done else { return }
        done = true
        interrupt?.cancel()
        stream?.stop()
        continuation.resume(returning: reason)
    }
}
