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
        var stdoutPipe: [Int32] = [0, 0]
        var stderrPipe: [Int32] = [0, 0]
        guard pipe(&stdoutPipe) == 0, pipe(&stderrPipe) == 0 else {
            return CommandResult(status: -1, stdout: Data(), stderr: "couldn't create a pipe", timedOut: false, truncated: false)
        }

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, stdoutPipe[1], 1)
        posix_spawn_file_actions_adddup2(&actions, stderrPipe[1], 2)
        for fd in stdoutPipe + stderrPipe { posix_spawn_file_actions_addclose(&actions, fd) }
        if let directory { posix_spawn_file_actions_addchdir_np(&actions, directory.path) }

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT))
        posix_spawnattr_setpgroup(&attributes, 0)

        let arguments = ["/bin/sh", "-c", command]
        let environmentStrings = environment.map { "\($0.key)=\($0.value)" }
        var pid: pid_t = 0
        let spawned = withCStrings(arguments) { argv in
            withCStrings(environmentStrings) { envp in
                posix_spawn(&pid, "/bin/sh", &actions, &attributes, argv, envp)
            }
        }
        close(stdoutPipe[1])
        close(stderrPipe[1])
        guard spawned == 0 else {
            close(stdoutPipe[0])
            close(stderrPipe[0])
            return CommandResult(status: -1, stdout: Data(), stderr: String(cString: strerror(spawned)), timedOut: false, truncated: false)
        }

        let readers = DispatchGroup()
        let stdout = Collector(limit: outputLimit)
        let stderr = Collector(limit: 64 * 1024)
        for (fd, collector) in [(stdoutPipe[0], stdout), (stderrPipe[0], stderr)] {
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

        var status: Int32 = 0
        while waitpid(pid, &status, 0) == -1 && errno == EINTR {}
        timer.cancel()
        // Anything the command left running in the background would keep the pipes open.
        kill(-pid, SIGKILL)
        _ = readers.wait(timeout: .now() + 2)

        let exitStatus: Int32 = (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
        return CommandResult(
            status: exitStatus, stdout: stdout.data, stderr: String(decoding: stderr.data, as: UTF8.self),
            timedOut: timedOut.isSet, truncated: stdout.truncated
        )
    }

    private static func withCStrings<R>(_ strings: [String], _ body: (UnsafePointer<UnsafeMutablePointer<CChar>?>) -> R) -> R {
        var pointers = strings.map { strdup($0) } + [nil]
        defer { pointers.forEach { free($0) } }
        return pointers.withUnsafeBufferPointer { body($0.baseAddress!) }
    }
}

/// Reads a pipe to its end, keeping at most `limit` bytes but always draining, so the command never
/// blocks on a full pipe.
private final class Collector: @unchecked Sendable {
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

private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() { lock.withLock { value = true } }
    var isSet: Bool { lock.withLock { value } }
}
