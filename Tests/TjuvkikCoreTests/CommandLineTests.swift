import Foundation
import Testing
@testable import TjuvkikCore

struct CLIArgumentsTests {
    private func command(_ arguments: String) throws -> CLIInvocation {
        try #require(CLIArguments.parse(arguments.split(separator: " ").map(String.init))).get()
    }

    private func usageError(_ arguments: String) -> String? {
        guard case .failure(let error) = CLIArguments.parse(arguments.split(separator: " ").map(String.init)) else { return nil }
        return error.message
    }

    @Test func noArgumentsOrLaunchArgumentsStartTheApp() {
        #expect(CLIArguments.parse([]) == nil)
        #expect(CLIArguments.parse(["-psn_0_12345"]) == nil)
        #expect(CLIArguments.parse(["-NSDocumentRevisionsDebugMode", "YES"]) == nil)
    }

    @Test func readsEachCommand() throws {
        #expect(try command("validate").command == .validate)
        #expect(try command("run cpu").command == .run(panel: "cpu", raw: false))
        #expect(try command("run cpu --raw").command == .run(panel: "cpu", raw: true))
        #expect(try command("preview cpu").command == .preview(panel: "cpu", size: nil, theme: nil, output: nil, scale: 2))
        #expect(try command("preview cpu --size l --theme dracula -o a.png --scale 3").command
            == .preview(panel: "cpu", size: .l, theme: "dracula", output: "a.png", scale: 3))
        #expect(try command("new prs").command == .new(name: "prs", type: "script"))
        #expect(try command("new prs --cli").command == .new(name: "prs", type: "cli"))
        #expect(try command("new prs --type=table").command == .new(name: "prs", type: "table"))
        #expect(try command("schema").command == .schema(name: nil))
        #expect(try command("schema panel").command == .schema(name: "panel"))
        #expect(try command("--help").command == .help)
        #expect(try command("run cpu -h").command == .help)
        #expect(try command("--version").command == .version)
    }

    @Test func readsTheConfigFolderAnywhere() throws {
        #expect(try command("--config /tmp/x validate").configDirectory == "/tmp/x")
        #expect(try command("validate --config=/tmp/x").configDirectory == "/tmp/x")
        #expect(try command("validate").configDirectory == nil)
    }

    @Test func explainsWrongUse() {
        #expect(usageError("frobnicate") == "unknown command \"frobnicate\"")
        #expect(usageError("run") == "run needs a panel name")
        #expect(usageError("run a b") == "run takes one panel name, got 2")
        #expect(usageError("run a --size m") == "run doesn't take --size")
        #expect(usageError("validate --raw") == "validate doesn't take --raw")
        #expect(usageError("preview a --size huge") == "unknown size \"huge\", expected s, m, l or xl")
        #expect(usageError("preview a --scale 9") == "--scale must be a number from 1 to 4, got \"9\"")
        #expect(usageError("preview a --theme") == "--theme needs a value")
        #expect(usageError("new a --cli --script") == "pick one of --type, --cli and --script")
        #expect(usageError("new a --type pie")?.hasPrefix("unknown type \"pie\"") == true)
        #expect(usageError("new ../a") == "\"../a\" can't be a panel name: use letters, digits, - and _")
        #expect(usageError("schema nope") == "unknown schema \"nope\", expected config, panel, theme")
        #expect(usageError("run a --frob") == "unknown option --frob")
    }
}

struct PanelTemplateTests {
    @Test func eachSampleIsItsType() throws {
        for type in PanelTemplate.types where type != "cli" {
            let content = ContentType(rawValue: type)
            let parsed = try ScriptOutput.content(Data(PanelTemplate.sample(content).utf8), as: content).get()
            #expect(parsed.type == content, "\(type)")
        }
    }

    @Test func newPanelsLoadAndValidate() throws {
        let fixture = ConfigFixture(["config.jsonc": #"{ "panels": [] }"#])
        for type in PanelTemplate.types {
            for file in PanelTemplate.files(name: "p-\(type)", type: type) {
                let url = fixture.directory.appending(path: file.path)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try file.text.write(to: url, atomically: true, encoding: .utf8)
            }
            let tile = try ConfigLoader.panel("p-\(type)", in: fixture.directory).get()
            #expect(tile.typeName == type)
            #expect(tile.command == "./p-\(type).sh")
        }
        let validation = ConfigValidation.check(fixture.directory)
        #expect(validation.errors.isEmpty)
        #expect(validation.warnings.isEmpty)
        #expect(validation.panels.count == PanelTemplate.types.count)
    }

    @Test func namesAreFolderSafe() {
        #expect(PanelTemplate.isValidName("pull-requests_2"))
        #expect(!PanelTemplate.isValidName(""))
        #expect(!PanelTemplate.isValidName("-a"))
        #expect(!PanelTemplate.isValidName("a/b"))
        #expect(!PanelTemplate.isValidName(".a"))
        #expect(!PanelTemplate.isValidName("a b"))
        #expect(PanelTemplate.title("release-notes") == "Release notes")
    }
}

struct ConfigValidationTests {
    private let panel = #"{ "type": "cli", "command": "date", "every": "60s" }"#

    @Test func checksPanelsNotOnTheBoard() {
        let validation = ConfigValidation.check(ConfigFixture([
            "config.jsonc": #"{ "panels": [{ "panel": "a" }] }"#,
            "panels/a/panel.jsonc": panel,
            "panels/b/panel.jsonc": #"{ "type": "cli", "command": "date", "size": "q" }"#,
        ]).directory)
        #expect(!validation.isValid)
        #expect(validation.errors.map(\.description) == [#"panels/b/panel.jsonc: size: unknown size "q", expected "s", "m", "l" or "xl""#])
        #expect(validation.panels == ["a", "b"])
        #expect(validation.report.hasSuffix("✗ 1 error in config.jsonc and 2 panels"))
    }

    @Test func reportsAnIssueOnce() {
        let validation = ConfigValidation.check(ConfigFixture([
            "config.jsonc": #"{ "panels": [{ "panel": "a" }] }"#,
            "panels/a/panel.jsonc": #"{ "type": "cli", "command": "date", "every": "1s" }"#,
        ]).directory)
        #expect(validation.errors.count == 1)
    }

    @Test func passesAValidConfig() {
        let validation = ConfigValidation.check(ConfigFixture([
            "config.jsonc": #"{ "panels": [{ "panel": "a" }] }"#,
            "panels/a/panel.jsonc": panel,
            "panels/b/panel.jsonc": panel,
            "panels/notes/readme.md": "not a panel",
        ]).directory)
        #expect(validation.isValid)
        #expect(validation.shown == ["a"])
        #expect(validation.report == "✓ config.jsonc and 2 panels are valid, 1 on the board")
    }

    @Test func failsWithoutAConfig() {
        let validation = ConfigValidation.check(ConfigFixture([:]).directory)
        #expect(!validation.isValid)
        #expect(validation.errors.first?.description.hasPrefix("config.jsonc: not found in") == true)
    }
}

struct SinglePanelLoadingTests {
    @Test func loadsAPanelByName() throws {
        let directory = ConfigFixture([
            "panels/a/panel.json": #"{ "type": "stats", "command": "./a.sh", "size": "l" }"#,
        ]).directory
        let tile = try ConfigLoader.panel("a", in: directory).get()
        #expect(tile.content == .stats)
        #expect(tile.size == .l)
        #expect(tile.slot == nil)
        #expect(tile.directory.lastPathComponent == "a")
    }

    @Test func namesAMissingPanel() {
        guard case .failure(let failure) = ConfigLoader.panel("nope", in: ConfigFixture([:]).directory) else {
            Issue.record("loaded a missing panel")
            return
        }
        #expect(failure.issues.map(\.description) == [#"no panel "nope": create panels/nope/panel.jsonc"#])
    }

    @Test func resolvesThemes() throws {
        let directory = ConfigFixture(["themes/mine.jsonc": #"{ "extends": "dracula" }"#]).directory
        #expect(try ConfigLoader.theme("dracula", in: directory).get() == .dracula)
        #expect(try ConfigLoader.theme("mine", in: directory).get().appearance == Theme.dracula.appearance)
        #expect((try? ConfigLoader.theme("nope", in: directory).get()) == nil)
    }
}

struct OutlineTests {
    @Test func saysWhatATileShows() throws {
        func outline(_ json: String, _ type: ContentType? = nil) throws -> String {
            try ScriptOutput.content(Data(json.utf8), as: type).get().outline
        }
        #expect(try outline(#"{ "rows": [{ "title": "a" }] }"#) == "rows, 1 row")
        #expect(try outline(#"{ "chart": { "value": 3 } }"#, .chart) == "chart, 3")
        #expect(try outline(#"{ "columns": [{ "title": "a" }], "rows": [["x"], ["y"]] }"#, .table) == "table, 1 column and 2 rows")
        #expect(ModuleContent.text("a\nb").outline == "text, 2 lines")
    }

    @Test func tileSizesMatchTheBoard() {
        let s = BentoGeometry.size(of: .s)
        let m = BentoGeometry.size(of: .m)
        #expect(m.width == s.width * 2 + BentoGeometry.gap)
        #expect(m.height == s.height)
        #expect(BentoGeometry.size(of: .l).height == s.height * 2 + BentoGeometry.gap)
    }
}
