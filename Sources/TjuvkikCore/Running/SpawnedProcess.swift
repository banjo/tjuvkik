import Darwin
import Foundation

/// `/bin/sh -c <command>` in its own process group, with stdout and stderr on pipes and stdin
/// from /dev/null. The group lets a stop or timeout end everything the command started.
struct SpawnedProcess: Sendable {
    struct Failure: Error { var message: String }

    let pid: pid_t
    let stdout: Int32
    let stderr: Int32

    static func start(_ command: String, directory: URL?, environment: [String: String]) -> Result<SpawnedProcess, Failure> {
        var stdoutPipe: [Int32] = [0, 0]
        var stderrPipe: [Int32] = [0, 0]
        guard pipe(&stdoutPipe) == 0 else { return .failure(Failure(message: "couldn't create a pipe")) }
        guard pipe(&stderrPipe) == 0 else {
            stdoutPipe.forEach { close($0) }
            return .failure(Failure(message: "couldn't create a pipe"))
        }

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, stdoutPipe[1], 1)
        posix_spawn_file_actions_adddup2(&actions, stderrPipe[1], 2)
        if let directory { posix_spawn_file_actions_addchdir_np(&actions, directory.path) }

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        // Only 0, 1 and 2 are inherited, and the command leads a new process group. Signals start
        // at their defaults, since ignored ones (the app ignores SIGTERM to handle it) carry over.
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK))
        posix_spawnattr_setpgroup(&attributes, 0)
        var allSignals = sigset_t()
        sigfillset(&allSignals)
        posix_spawnattr_setsigdefault(&attributes, &allSignals)
        var noSignals = sigset_t()
        sigemptyset(&noSignals)
        posix_spawnattr_setsigmask(&attributes, &noSignals)

        var pid: pid_t = 0
        let spawned = withCStrings(["/bin/sh", "-c", command]) { argv in
            withCStrings(environment.map { "\($0.key)=\($0.value)" }) { envp in
                posix_spawn(&pid, "/bin/sh", &actions, &attributes, argv, envp)
            }
        }
        close(stdoutPipe[1])
        close(stderrPipe[1])
        guard spawned == 0 else {
            close(stdoutPipe[0])
            close(stderrPipe[0])
            return .failure(Failure(message: String(cString: strerror(spawned))))
        }
        return .success(SpawnedProcess(pid: pid, stdout: stdoutPipe[0], stderr: stderrPipe[0]))
    }

    /// Signals the whole group.
    func signal(_ signal: Int32) {
        kill(-pid, signal)
    }

    /// Waits for the shell to exit, then kills what it left running in the background, which
    /// would keep the pipes open, unless `keepingBackground`. Returns the exit status (128 +
    /// signal when killed).
    func wait(keepingBackground: Bool = false) -> Int32 {
        var status: Int32 = 0
        while waitpid(pid, &status, 0) == -1 && errno == EINTR {}
        if !keepingBackground { signal(SIGKILL) }
        return (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
    }

    private static func withCStrings<R>(_ strings: [String], _ body: (UnsafePointer<UnsafeMutablePointer<CChar>?>) -> R) -> R {
        var pointers = strings.map { strdup($0) } + [nil]
        defer { pointers.forEach { free($0) } }
        return pointers.withUnsafeBufferPointer { body($0.baseAddress!) }
    }
}
