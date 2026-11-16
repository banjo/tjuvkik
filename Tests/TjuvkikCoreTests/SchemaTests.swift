import Foundation
import Testing
@testable import TjuvkikCore

/// The schemas in `schema/` are written by hand for editor completion. These tests fail when they
/// drift from what the loader reads, so a new key or value has to be added to both.
struct SchemaTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func schema(_ name: String) throws -> [String: Any] {
        let data = try Data(contentsOf: Self.root.appending(path: "schema/\(name).schema.json"))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// The keys a raw file type decodes, read from an empty instance.
    private func keys(_ value: Any) -> Set<String> {
        Set(Mirror(reflecting: value).children.compactMap(\.label))
    }

    private func properties(_ object: Any?) -> [String: [String: Any]] {
        ((object as? [String: Any])?["properties"] as? [String: [String: Any]]) ?? [:]
    }

    private func enumValues(_ property: [String: Any]?) -> Set<String> {
        Set((property?["enum"] as? [String]) ?? [])
    }

    @Test func configKeys() throws {
        let config = properties(try schema("config"))
        #expect(Set(config.keys) == keys(RawConfig()).union(["$schema"]))
        #expect(Set(properties(config["trigger"]).keys) == keys(RawTrigger()))
        #expect(Set(properties(config["panels"]?["items"]).keys) == keys(RawPanelRef()))
    }

    @Test func configValues() throws {
        let config = properties(try schema("config"))
        #expect(enumValues(config["view"]) == Set(Config.View.allCases.map(\.rawValue)))
        #expect(enumValues(config["layout"]) == Set(Config.Layout.allCases.map(\.rawValue)))
        #expect(Set(config["theme"]?["examples"] as? [String] ?? []) == Set(Theme.builtIn.keys))
        #expect(enumValues(properties(config["panels"]?["items"])["size"]) == Set(TileSize.allCases.map(\.rawValue)))
        #expect(Set(properties(config["panels"]?["items"])["panel"]?["examples"] as? [String] ?? []) == Set(ConfigLoader.builtInPanels))
    }

    @Test func panelSchema() throws {
        let panel = properties(try schema("panel"))
        #expect(Set(panel.keys) == keys(RawPanel()).union(["$schema"]))
        #expect(enumValues(panel["type"]) == Set(ConfigLoader.panelTypes))
        #expect(enumValues(panel["size"]) == Set(TileSize.allCases.map(\.rawValue)))
    }

    @Test func themeSchema() throws {
        let theme = properties(try schema("theme"))
        #expect(Set(theme.keys) == keys(RawTheme()).union(["$schema"]))
        #expect(enumValues(theme["appearance"]) == Set(Theme.Appearance.allCases.map(\.rawValue)))
        #expect(Set(theme["extends"]?["examples"] as? [String] ?? []) == Set(Theme.builtIn.keys))
    }

    @Test func defaultFilesPointAtTheSchemas() throws {
        let fixture = ConfigFixture([:])
        try DefaultConfig.write(to: fixture.directory)
        for (path, text) in DefaultConfig.files {
            let line = try #require(text.split(separator: "\n").first { $0.contains("\"$schema\"") })
            let relative = try #require(line.split(separator: "\"").dropFirst(3).first)
            let schemaName = URL(fileURLWithPath: String(relative)).lastPathComponent
            let target = fixture.directory.appending(path: path).deletingLastPathComponent().appending(path: String(relative)).standardized
            #expect(target.path == fixture.directory.appending(path: "schemas/\(schemaName)").standardized.path)
            #expect(FileManager.default.fileExists(atPath: Self.root.appending(path: "schema/\(schemaName)").path))
        }
    }
}
