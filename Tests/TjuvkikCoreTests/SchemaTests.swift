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
        #expect(Set(properties(config["pause"]).keys) == keys(RawPause()))
        #expect(Set(properties(config["notifications"]).keys) == keys(RawNotifications()))
    }

    @Test func configValues() throws {
        let config = properties(try schema("config"))
        #expect(enumValues(config["view"]) == Set(Config.View.allCases.map(\.rawValue)))
        #expect(enumValues(config["layout"]) == Set(Config.Layout.allCases.map(\.rawValue)))
        let themeName = (config["theme"]?["anyOf"] as? [[String: Any]])?.first { $0["type"] as? String == "string" }
        #expect(Set(themeName?["examples"] as? [String] ?? []) == Set(Theme.builtIn.keys))
        #expect(enumValues(properties(config["panels"]?["items"])["size"]) == Set(TileSize.allCases.map(\.rawValue)))
        #expect(enumValues(properties(config["trigger"])["key"]) == Set(Trigger.Key.allCases.map(\.rawValue)))
        #expect(enumValues(properties(config["trigger"])["mode"]) == Set(Trigger.Mode.allCases.map(\.rawValue)))
    }

    @Test func panelSchema() throws {
        let panel = properties(try schema("panel"))
        #expect(Set(panel.keys) == keys(RawPanel()).union(["$schema"]))
        #expect(enumValues(panel["type"]) == Set(Tile.Kind.allCases.map(\.rawValue) + ContentType.allCases.map(\.rawValue)))
        #expect(enumValues(panel["mode"]) == Set(Tile.Mode.allCases.map(\.rawValue)))
        #expect(enumValues(panel["size"]) == Set(TileSize.allCases.map(\.rawValue)))
        let option = panel["options"]?["additionalProperties"]
        #expect(Set(properties(option).keys) == keys(RawOption()))
        #expect(enumValues(properties(option)["type"]) == Set(PanelOption.Kind.allCases.map(\.rawValue)))
    }

    @Test func themeSchema() throws {
        let theme = properties(try schema("theme"))
        #expect(Set(theme.keys) == keys(RawTheme()).union(["$schema"]))
        #expect(enumValues(theme["appearance"]) == Set(Theme.Appearance.allCases.map(\.rawValue)))
        #expect(Set(theme["extends"]?["examples"] as? [String] ?? []) == Set(Theme.builtIn.keys))
        #expect(enumValues(theme["material"]) == Set(Theme.Material.allCases.map(\.rawValue)))
        #expect(Set(properties(theme["font"]).keys) == keys(RawThemeFont()))
        #expect(Set(properties(theme["board"]).keys) == keys(RawThemeBoard()))
        #expect(Set(properties(theme["tile"]).keys) == keys(RawThemeTile()))
        #expect(Set(properties(properties(theme["tile"])["header"]).keys) == keys(RawThemeHeader()))
        #expect(Set(properties(theme["tones"]).keys) == Set(Tone.allCases.filter { $0 != .normal }.map(\.rawValue)))
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
