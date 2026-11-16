import Darwin
import Foundation

public struct CommandResult: Equatable, Sendable {
    public var status: Int32
    public var stdout: Data
    public var stderr: String
    public var timedOut: Bool
    /// stdout was longer than the limit and was cut.
    public var truncated: Bool

    public var succeeded: Bool { status == 0 && !timedOut }

    /// The last few lines of stderr, or what went wrong when there are none.
    public func failureSummary(timeout: Double) -> String {
        if timedOut { return "timed out after \(timeout.secondsText)s" }
        let lines = stderr.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return lines.suffix(2).joined(separator: " ").nonEmpty ?? "exited with status \(status)"
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

/// Runs shell commands for panels. Each command gets its own process group, so a timeout stops
/// everything it started, not just the shell.
public enum CommandRunner {
    public static let outputLimit = 256 * 1024

    public static func run(
        _ command: String,
        in directory: URL? = nil,
        environment: [String: String],
        timeout: Double,
        outputLimit: Int = outputLimit
    ) async -> CommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: runBlocking(command, directory: directory, environment: environment, timeout: timeout, outputLimit: outputLimit))
            }
        }
    }

    private static func runBlocking(_ command: String, directory: URL?, environment: [String: String], timeout: Double, outputLimit: Int) -> CommandResult {
        let process: SpawnedProcess
        switch SpawnedProcess.start(command, directory: directory, environment: environment) {
        case .success(let spawned): process = spawned
        case .failure(let error): return CommandResult(status: -1, stdout: Data(), stderr: error.message, timedOut: false, truncated: false)
        }
        let pid = process.pid

        let readers = DispatchGroup()
        let stdout = Collector(limit: outputLimit)
        let stderr = Collector(limit: 64 * 1024)
        for (fd, collector) in [(process.stdout, stdout), (process.stderr, stderr)] {
            readers.enter()
            DispatchQueue.global(qos: .utility).async {
                collector.drain(fd)
                close(fd)
                readers.leave()
            }
        }

        let timedOut = Flag()
        let timer = DispatchWorkItem {
            timedOut.set()
            kill(-pid, SIGTERM)
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) { kill(-pid, SIGKILL) }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timer)

        let exitStatus = process.wait()
        timer.cancel()
        _ = readers.wait(timeout: .now() + 2)

        return CommandResult(
            status: exitStatus, stdout: stdout.data, stderr: String(decoding: stderr.data, as: UTF8.self),
            timedOut: timedOut.isSet, truncated: stdout.truncated
        )
    }
}

/// Reads a pipe to its end, keeping at most `limit` bytes but always draining, so the command never
/// blocks on a full pipe.
final class Collector: @unchecked Sendable {
    private let limit: Int
    private(set) var data = Data()
    private(set) var truncated = false

    init(limit: Int) { self.limit = limit }

    func drain(_ fd: Int32) {
        var buffer = [UInt8](repeating: 0, count: 16 * 1024)
        while true {
            let count = read(fd, &buffer, buffer.count)
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { return }
            let room = limit - data.count
            if room > 0 { data.append(contentsOf: buffer.prefix(min(count, room))) }
            if count > room { truncated = true }
        }
    }
}

final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() { lock.withLock { value = true } }
    var isSet: Bool { lock.withLock { value } }
}
