import Foundation
import Testing
@testable import TjuvkikCore

struct CommandRunnerTests {
    private let environment = ["PATH": "/usr/bin:/bin"]

    @Test func capturesOutputAndStatus() async {
        let result = await CommandRunner.run("echo out; echo err >&2; exit 3", environment: environment, timeout: 5)
        #expect(String(decoding: result.stdout, as: UTF8.self) == "out\n")
        #expect(result.stderr == "err\n")
        #expect(result.status == 3)
        #expect(!result.succeeded)
        #expect(result.failureSummary(timeout: 5) == "err")
    }

    @Test func runsInTheGivenDirectoryWithTheEnvironment() async {
        let result = await CommandRunner.run("pwd; echo $GREETING", in: URL(fileURLWithPath: "/usr"), environment: environment.merging(["GREETING": "hej"]) { $1 }, timeout: 5)
        #expect(String(decoding: result.stdout, as: UTF8.self) == "/usr\nhej\n")
        #expect(result.succeeded)
    }

    @Test func timeoutStopsTheWholeGroup() async {
        let start = Date()
        // The background sleep keeps stdout open; it must be killed too, or this would hang.
        let result = await CommandRunner.run("sleep 30 & sleep 30", environment: environment, timeout: 0.3)
        #expect(result.timedOut)
        #expect(Date().timeIntervalSince(start) < 3)
        #expect(result.failureSummary(timeout: 0.3) == "timed out after 0.3s")
    }

    @Test func outputIsCappedButDrained() async {
        let result = await CommandRunner.run("head -c 100000 /dev/zero", environment: environment, timeout: 5, outputLimit: 1000)
        #expect(result.stdout.count == 1000)
        #expect(result.truncated)
        #expect(result.succeeded)
    }

    @Test func missingCommand() async {
        let result = await CommandRunner.run("definitely-not-a-command", environment: environment, timeout: 5)
        #expect(result.status == 127)
        #expect(result.failureSummary(timeout: 5).contains("not found"))
    }

    @Test func loginPathMarkers() {
        #expect(LoginEnvironment.path(from: "motd junk\n__TJUVKIK_PATH__/a:/b__TJUVKIK_PATH__") == "/a:/b")
        #expect(LoginEnvironment.path(from: "no markers") == nil)
    }
}
