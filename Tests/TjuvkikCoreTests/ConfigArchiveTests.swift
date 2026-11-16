import Foundation
import Testing
@testable import TjuvkikCore

struct ConfigArchiveTests {
    private let temp = FileManager.default.temporaryDirectory.appending(path: "tjuvkik-tests/\(UUID().uuidString)")

    @Test func exportThenImportRoundTrips() throws {
        let source = ConfigFixture([
            "config.json": #"{ "theme": "mine", "panels": [{ "panel": "x" }] }"#,
            "themes/mine.json": #"{ "extends": "dracula" }"#,
            "panels/x/panel.json": #"{ "type": "cli", "command": "./run.sh" }"#,
            "panels/x/run.sh": "echo hi",
            "schemas/config.schema.json": "{}",
        ])
        let zip = temp.appending(path: "out.zip")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        try ConfigArchive.export(source.directory, to: zip)

        let target = ConfigFixture(["config.json": "{}", "panels/old/panel.json": "{}"])
        let backup = temp.appending(path: "backups/backup.zip")
        try ConfigArchive.import(zip, into: target.directory, backup: backup)

        let config = try target.load().get().config
        #expect(config.theme == .dracula)
        #expect(config.tiles.map(\.panel) == ["x"])
        let files = FileManager.default.subpaths(atPath: target.directory.path)!.sorted()
        #expect(files.contains("panels/x/run.sh"))
        #expect(!files.contains("panels/old"))
        #expect(!files.contains("schemas"))
        #expect(FileManager.default.fileExists(atPath: backup.path))
    }

    @Test func invalidZipIsRefusedAndNothingChanges() throws {
        let source = ConfigFixture(["config.json": #"{ "theme": "nope" }"#])
        let zip = temp.appending(path: "bad.zip")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        try ConfigArchive.export(source.directory, to: zip)

        let target = ConfigFixture(["config.json": #"{ "theme": "dracula" }"#])
        #expect(throws: ConfigArchive.Failure.self) {
            try ConfigArchive.import(zip, into: target.directory, backup: temp.appending(path: "b.zip"))
        }
        #expect(try target.load().get().config.theme == .dracula)
    }

    @Test func fingerprintChangesWhenAPanelIsAdded() throws {
        let fixture = ConfigFixture(["config.json": "{}"])
        let before = ConfigFingerprint.of(fixture.directory)
        let panel = fixture.directory.appending(path: "panels/new/panel.json")
        try FileManager.default.createDirectory(at: panel.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{}".write(to: panel, atomically: true, encoding: .utf8)
        #expect(ConfigFingerprint.of(fixture.directory) != before)
    }
}
