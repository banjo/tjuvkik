import Foundation

/// The environment panel commands run with. Apps started from Finder or at login get a bare PATH,
/// so this takes PATH from your login shell once, which makes Homebrew, `gh` and `kubectl` work.
public enum LoginEnvironment {
    public static let fallbackPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    private static let marker = "__TJUVKIK_PATH__"

    public static func load() async -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let shell = environment["SHELL"] ?? "/bin/zsh"
        // Interactive, so PATH set in .zshrc is included; the markers skip anything the shell prints.
        let result = await CommandRunner.run(
            "\(shell) -lic 'printf \"\(marker)%s\(marker)\" \"$PATH\"'",
            environment: environment, timeout: 10
        )
        environment["PATH"] = path(from: String(decoding: result.stdout, as: UTF8.self)) ?? fallbackPath
        environment["NO_COLOR"] = "1"
        environment["TERM"] = "dumb"
        environment["COLUMNS"] = "160"
        return environment
    }

    static func path(from output: String) -> String? {
        let parts = output.components(separatedBy: marker)
        guard parts.count >= 3, !parts[1].isEmpty else { return nil }
        return parts[1]
    }
}
