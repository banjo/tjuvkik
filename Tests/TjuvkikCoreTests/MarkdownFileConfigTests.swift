import Foundation
import Testing
@testable import TjuvkikCore

/// A markdown panel can read a file instead of running a command:
/// `{ "type": "markdown", "file": "~/notes/today.md" }`.
struct MarkdownFileConfigTests {
    private func panel(_ json: String) -> [String: String] {
        ["config.jsonc": #"{ "panels": [{ "panel": "today" }] }"#, "panels/today/panel.jsonc": json]
    }

    @Test func aFileNeedsNoCommand() throws {
        let tile = try load(panel(#"{ "type": "markdown", "file": "~/notes/today.md" }"#)).config.tiles[0]
        #expect(tile.kind == .script)
        #expect(tile.content == .markdown)
        #expect(tile.command == "")
        #expect(tile.file?.path == NSString(string: "~/notes/today.md").expandingTildeInPath)
        #expect(tile.file?.path.hasPrefix("~") == false)
    }

    @Test func aRelativePathIsInThePanelsFolder() throws {
        let fixture = ConfigFixture(panel(#"{ "type": "markdown", "file": "notes.md" }"#))
        let tile = try fixture.load().get().config.tiles[0]
        #expect(tile.file?.standardizedFileURL.path == fixture.directory.appending(path: "panels/today/notes.md").standardizedFileURL.path)
    }

    @Test func anAbsolutePathIsKept() throws {
        let tile = try load(panel(#"{ "type": "markdown", "file": "/tmp/today.md" }"#)).config.tiles[0]
        #expect(tile.file?.path == "/tmp/today.md")
    }

    @Test func aCommandStillWorks() throws {
        let tile = try load(panel(#"{ "type": "markdown", "command": "cat today.md" }"#)).config.tiles[0]
        #expect(tile.command == "cat today.md")
        #expect(tile.file == nil)
    }

    @Test func onlyMarkdownReadsAFile() {
        #expect(errors(panel(#"{ "type": "cli", "command": "ls", "file": "a.md" }"#))
            == ["panels/today/panel.jsonc: file: only a markdown panel can read a file"])
        #expect(errors(panel(#"{ "type": "script", "file": "a.md" }"#))
            == ["panels/today/panel.jsonc: file: only a markdown panel can read a file"])
    }

    @Test func notBothFileAndCommand() {
        #expect(errors(panel(#"{ "type": "markdown", "file": "a.md", "command": "cat a.md" }"#))
            == [#"panels/today/panel.jsonc: command: a panel reads either a file or a command's output, not both"#])
    }

    @Test func markdownNeedsAFileOrACommand() {
        #expect(errors(panel(#"{ "type": "markdown" }"#)) == ["panels/today/panel.jsonc: command: a markdown panel needs a command or a file"])
        #expect(errors(panel(#"{ "type": "stats" }"#)) == ["panels/today/panel.jsonc: command: a script panel needs a command"])
    }

    @Test func anEmptyFile() {
        #expect(errors(panel(#"{ "type": "markdown", "file": " " }"#)) == ["panels/today/panel.jsonc: file: can't be empty"])
    }

    @Test func aFileDoesntStream() {
        #expect(errors(panel(#"{ "type": "markdown", "mode": "stream", "file": "a.md" }"#))
            == ["panels/today/panel.jsonc: mode: a file panel reloads when the file changes, so it can't stream"])
    }
}
