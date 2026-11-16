import Darwin
import Foundation

/// Runs a command that keeps running, and hands over each line it prints as it comes.
public final class CommandStream: @unchecked Sendable {
    public struct Exit: Sendable {
        public var status: Int32
        public var stderr: String
        /// Stopped with `stop()`, not on its own.
        public var stopped: Bool

        public var summary: String {
            let lines = stderr.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let tail = lines.suffix(2).joined(separator: " ")
            return tail.isEmpty ? "exited with status \(status)" : tail
        }
    }

    /// Longer lines are cut, so a runaway command can't use up memory.
    public static let lineLimit = 1024 * 1024

    private let process: SpawnedProcess?
    private let lock = NSLock()
    private var stopped = false

    /// `onLine` and `onExit` are called on a background queue. `onExit` is called once, also
    /// when the command couldn't start.
    public init(
        _ command: String,
        in directory: URL? = nil,
        environment: [String: String],
        onLine: @escaping @Sendable (String) -> Void,
        onExit: @escaping @Sendable (Exit) -> Void
    ) {
        switch SpawnedProcess.start(command, directory: directory, environment: environment) {
        case .failure(let error):
            process = nil
            DispatchQueue.global().async { onExit(Exit(status: -1, stderr: error.message, stopped: false)) }
        case .success(let process):
            self.process = process
            let readers = DispatchGroup()
            let stderr = Collector(limit: 8 * 1024)
            readers.enter()
            DispatchQueue.global(qos: .utility).async {
                Self.readLines(process.stdout, onLine: onLine)
                close(process.stdout)
                readers.leave()
            }
            readers.enter()
            DispatchQueue.global(qos: .utility).async {
                stderr.drain(process.stderr)
                close(process.stderr)
                readers.leave()
            }
            DispatchQueue.global(qos: .utility).async { [self] in
                let status = process.wait()
                _ = readers.wait(timeout: .now() + 2)
                let wasStopped = lock.withLock { stopped }
                onExit(Exit(status: status, stderr: String(decoding: stderr.data, as: UTF8.self), stopped: wasStopped))
            }
        }
    }

    /// Ends the command and everything it started.
    public func stop() {
        guard let process else { return }
        let first = lock.withLock {
            defer { stopped = true }
            return !stopped
        }
        guard first else { return }
        process.signal(SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { process.signal(SIGKILL) }
    }

    private static func readLines(_ fd: Int32, onLine: @Sendable (String) -> Void) {
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        var line = Data()
        var overflow = false
        while true {
            let count = read(fd, &buffer, buffer.count)
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { break }
            var start = 0
            for index in 0..<count where buffer[index] == UInt8(ascii: "\n") {
                if !overflow { line.append(contentsOf: buffer[start..<index]) }
                onLine(String(decoding: line, as: UTF8.self))
                line.removeAll(keepingCapacity: true)
                overflow = false
                start = index + 1
            }
            if start < count, !overflow {
                line.append(contentsOf: buffer[start..<count])
                if line.count > lineLimit {
                    line = line.prefix(lineLimit)
                    overflow = true
                }
            }
        }
        if !line.isEmpty { onLine(String(decoding: line, as: UTF8.self)) }
    }
}
