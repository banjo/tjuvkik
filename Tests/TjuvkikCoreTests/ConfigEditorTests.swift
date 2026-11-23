import Foundation
import Testing
@testable import TjuvkikCore

struct ConfigEditorTests {
    private func edit(_ text: String, _ change: (inout ConfigEditor) throws -> Void) throws -> String {
        var editor = try ConfigEditor(text)
        try change(&editor)
        return editor.text
    }

    private func shortcut(_ text: String) throws -> Shortcut { try Shortcut.parse(text).get() }

    // MARK: General

    @Test func launchAtLogin() throws {
        let off = try edit("""
        {
          "launchAtLogin": true, // starts with the Mac
        }
        """) { try $0.setLaunchAtLogin(false) }
        #expect(off == """
        {
          "launchAtLogin": false, // starts with the Mac
        }
        """)
        #expect(try edit(off) { try $0.setLaunchAtLogin(true) } == "{\n}")
    }

    @Test func gridAndZoom() throws {
        let set = try edit("{\n}") {
            try $0.setGrid(BoardGrid(columns: 6, rows: 4))
            try $0.setZoom(.fixed(1.25))
        }
        #expect(try load(["config.json": set]).config.grid == BoardGrid(columns: 6, rows: 4))
        #expect(try load(["config.json": set]).config.zoom == .fixed(1.25))
        #expect(try edit(set) {
            try $0.setGrid(.standard)
            try $0.setZoom(.auto)
        } == "{\n}")
    }

    @Test func dimAndFocusOnOpen() throws {
        let some = try edit("{\n}") {
            try $0.setDim(Config.defaultDim)
            try $0.setFocusOnOpen(.last)
        }
        #expect(some.contains(#""dim": true"#))
        #expect(try load(["config.json": some]).config.focusOnOpen == .last)
        let more = try edit(some) { try $0.setDim(0.7) }
        #expect(try load(["config.json": more]).config.dim == 0.7)
        #expect(try edit(more) {
            try $0.setDim(0)
            try $0.setFocusOnOpen(.urgent)
        } == "{\n}")
    }

    @Test func jumpKey() throws {
        let text = try edit("{\n}") { try $0.setJumpKey(.shift) }
        #expect(try load(["config.json": text]).config.jumpKey == .shift)
        #expect(try edit(text) { try $0.setJumpKey(.option) } == "{\n}")
    }

    @Test func viewAndSearch() throws {
        let text = try edit("{\n}") {
            try $0.setView(.spotlight)
            try $0.setSearch(false)
        }
        let config = try load(["config.json": text]).config
        #expect(config.view == .spotlight)
        #expect(!config.search)
        #expect(try edit(text) {
            try $0.setView(.bento)
            try $0.setSearch(true)
        } == "{\n}")
    }

    @Test func pause() throws {
        let text = try edit("{\n  \"view\": \"bento\",\n}") { try $0.setPause(whenLocked: false, onLowPower: true) }
        #expect(text == """
        {
          "view": "bento",
          "pause": { "whenLocked": false },
        }
        """)
        #expect(try edit(text) { try $0.setPause(whenLocked: true, onLowPower: true) } == "{\n  \"view\": \"bento\",\n}")
    }

    @Test func notifications() throws {
        let text = try edit("{\n  \"view\": \"bento\",\n}") {
            try $0.setNotifications(enabled: true, sound: false, quietHours: "22:00-07:00", whileOpen: true)
        }
        #expect(text == """
        {
          "view": "bento",
          "notifications": { "sound": false, "quietHours": "22:00-07:00", "whileOpen": true },
        }
        """)
        #expect(try edit(text) { try $0.setNotifications(enabled: false, sound: true, quietHours: nil, whileOpen: false) } == """
        {
          "view": "bento",
          "notifications": { "enabled": false },
        }
        """)
        #expect(try edit(text) { try $0.setNotifications(enabled: true, sound: true, quietHours: nil, whileOpen: false) } == "{\n  \"view\": \"bento\",\n}")
    }

    // MARK: Trigger

    @Test func triggerKeyKeepsComments() throws {
        let text = """
        {
          "trigger": {
            // my favourite
            "key": "fn",
            "holdMs": 250,
          },
        }
        """
        #expect(try edit(text) { try $0.setTrigger(Trigger(input: .key(.rightOption), mode: .hold, holdMilliseconds: 400)) } == """
        {
          "trigger": {
            // my favourite
            "key": "rightOption",
            "holdMs": 400,
          },
        }
        """)
        #expect(try edit(text) { try $0.setTrigger(Trigger(input: .key(.fn), mode: .doubleTap, doubleTapMilliseconds: 300)) } == """
        {
          "trigger": {
            // my favourite
            "mode": "doubleTap",
          },
        }
        """)
    }

    @Test func triggerCloseOnClickOutside() throws {
        let text = #"{ "trigger": { "mode": "toggle" } }"#
        #expect(try edit(text) { try $0.setTrigger(Trigger(input: .key(.fn), mode: .toggle, closeOnClickOutside: false)) } == #"{ "trigger": { "mode": "toggle", "closeOnClickOutside": false } }"#)
    }

    @Test func triggerShortcut() throws {
        let text = #"{ "trigger": { "key": "fn", "holdMs": 250 } }"#
        #expect(try edit(text) { try $0.setTrigger(Trigger(input: .shortcut(shortcut("⌃⌥Space")), mode: .toggle)) } == #"{ "trigger": { "shortcut": "⌃⌥Space" } }"#)
        #expect(try edit(text) { try $0.setTrigger(Trigger(input: .shortcut(shortcut("ctrl+g")), mode: .hold, holdMilliseconds: 250)) } == #"{ "trigger": { "shortcut": "⌃G", "mode": "hold" } }"#)
    }

    @Test func triggerAtDefaultsIsRemoved() throws {
        #expect(try edit(#"{ "view": "bento", "trigger": { "key": "fn", "holdMs": 250 } }"#) { try $0.setTrigger(.fn) } == #"{ "view": "bento" }"#)
        #expect(try edit(#"{ "trigger": { "key": "rightShift", "mode": "toggle", "doubleTapMs": 400 } }"#) {
            try $0.setTrigger(Trigger(input: .key(.rightShift), mode: .toggle, doubleTapMilliseconds: 400))
        } == #"{ "trigger": { "key": "rightShift", "mode": "toggle" } }"#)
    }

    @Test func triggerCreated() throws {
        #expect(try edit("{}") { try $0.setTrigger(Trigger(input: .key(.fn), mode: .hold, holdMilliseconds: 500)) } == #"{ "trigger": { "holdMs": 500 } }"#)
    }

    // MARK: Theme

    @Test func theme() throws {
        let text = "{\n  \"theme\": \"dark-glass\", // mine\n}"
        #expect(try edit(text) { try $0.setTheme("dracula") } == "{\n  \"theme\": \"dracula\", // mine\n}")
        #expect(try edit(#"{ "theme": "dracula" }"#) { try $0.setTheme("dark-glass") } == "{}")
    }

    @Test func themePair() throws {
        let pair = try edit(#"{ "theme": "dracula" }"#) { try $0.setTheme(light: "light-glass", dark: "dracula") }
        #expect(pair == #"{ "theme": { "light": "light-glass", "dark": "dracula" } }"#)
        #expect(try edit(pair) { try $0.setTheme(light: "mine", dark: "dracula") } == #"{ "theme": { "light": "mine", "dark": "dracula" } }"#)
        #expect(try edit(pair) { try $0.setTheme(light: "dracula", dark: "dracula") } == #"{ "theme": "dracula" }"#)
    }

    // MARK: Tiles

    private let board = """
    {
      "panels": [
        { "panel": "agents" },
        // CI
        { "panel": "ci", "id": "ci-main" },
        { "size": "m" },
        { "panel": "disk" },
      ],
    }
    """

    @Test func entries() throws {
        #expect(try ConfigEditor(board).entries() == [
            .init(index: 0, panel: "agents"),
            .init(index: 1, panel: "ci", id: "ci-main"),
            .init(index: 3, panel: "disk"),
        ])
        #expect(try ConfigEditor(board).entries()[1].resolvedID == "ci-main")
    }

    @Test func addTile() throws {
        let text = try edit(#"{ "panels": [{ "panel": "ci" }, { "panel": "ci", "id": "ci-2" }] }"#) {
            try $0.addTile(panel: "disk")
            try $0.addTile(panel: "ci")
        }
        #expect(text == #"{ "panels": [{ "panel": "ci" }, { "panel": "ci", "id": "ci-2" }, { "panel": "disk" }, { "panel": "ci", "id": "ci-3" }] }"#)
        #expect(try edit("{}") { try $0.addTile(panel: "disk") } == #"{ "panels": [{ "panel": "disk" }] }"#)
    }

    @Test func removeTile() throws {
        let text = try edit("""
        {
          "menuBar": ["agents", "disk"],
          "panels": [
            { "panel": "agents" },
            { "panel": "disk" },
          ],
        }
        """) { try $0.removeTile(at: 0) }
        #expect(text == """
        {
          "menuBar": "disk",
          "panels": [
            { "panel": "disk" },
          ],
        }
        """)
    }

    @Test func moveTile() throws {
        #expect(try edit(board) { try $0.moveTile(from: 3, to: 0) } == """
        {
          "panels": [
            { "panel": "disk" },
            { "panel": "agents" },
            // CI
            { "panel": "ci", "id": "ci-main" },
            { "size": "m" },
          ],
        }
        """)
    }

    @Test func setTile() throws {
        let sized = try edit(board) {
            try $0.setTile(0, .size, .string("l"))
            try $0.setTile(1, .notify, .bool(false))
            try $0.setTile(1, .title, nil)
        }
        #expect(sized == """
        {
          "panels": [
            { "panel": "agents", "size": "l" },
            // CI
            { "panel": "ci", "id": "ci-main", "notify": false },
            { "size": "m" },
            { "panel": "disk" },
          ],
        }
        """)
        #expect(try edit(sized) {
            try $0.setTile(0, .size, nil)
            try $0.setTile(1, .notify, nil)
        } == board)
    }

    @Test func renameTile() throws {
        let text = #"{ "menuBar": "ci-main", "panels": [{ "panel": "ci", "id": "ci-main" }] }"#
        #expect(try edit(text) { try $0.renameTile(0, to: "build") } == #"{ "menuBar": "build", "panels": [{ "panel": "ci", "id": "build" }] }"#)
        #expect(try edit(text) { try $0.renameTile(0, to: nil) } == #"{ "menuBar": "ci", "panels": [{ "panel": "ci" }] }"#)
        #expect(try edit(text) { try $0.renameTile(0, to: "ci") } == #"{ "menuBar": "ci", "panels": [{ "panel": "ci" }] }"#)
        let array = #"{ "menuBar": ["a", "ci-main"], "panels": [{ "panel": "a" }, { "panel": "ci", "id": "ci-main" }] }"#
        #expect(try edit(array) { try $0.renameTile(1, to: "b") } == #"{ "menuBar": ["a", "b"], "panels": [{ "panel": "a" }, { "panel": "ci", "id": "b" }] }"#)
    }

    @Test func setOption() throws {
        let text = try edit(#"{ "panels": [{ "panel": "ci" }] }"#) {
            try $0.setOption(0, "repo", .string("a/b"))
            try $0.setOption(0, "limit", .number(10))
        }
        #expect(text == #"{ "panels": [{ "panel": "ci", "options": { "repo": "a/b", "limit": 10 } }] }"#)
        let one = try edit(text) { try $0.setOption(0, "repo", nil) }
        #expect(one == #"{ "panels": [{ "panel": "ci", "options": { "limit": 10 } }] }"#)
        #expect(try edit(one) { try $0.setOption(0, "limit", nil) } == #"{ "panels": [{ "panel": "ci" }] }"#)
    }

    @Test func menuBar() throws {
        let tiles = #""panels": [{ "panel": "a" }, { "panel": "b" }, { "panel": "c" }]"#
        let none = "{ \(tiles) }"
        let one = try edit(none) { try $0.setInMenuBar("c", true) }
        #expect(one == #"{ "panels": [{ "panel": "a" }, { "panel": "b" }, { "panel": "c" }], "menuBar": "c" }"#)
        let two = try edit(one) { try $0.setInMenuBar("a", true) }
        #expect(two == #"{ "panels": [{ "panel": "a" }, { "panel": "b" }, { "panel": "c" }], "menuBar": ["a", "c"] }"#)
        let three = try edit(two) { try $0.setInMenuBar("b", true) }
        #expect(three == #"{ "panels": [{ "panel": "a" }, { "panel": "b" }, { "panel": "c" }], "menuBar": ["a", "b", "c"] }"#)
        #expect(try edit(three) { try $0.setInMenuBar("b", true) } == three)
        #expect(try edit(three) { try $0.setInMenuBar("a", false) } == #"{ "panels": [{ "panel": "a" }, { "panel": "b" }, { "panel": "c" }], "menuBar": ["b", "c"] }"#)
        #expect(try edit(two) { try $0.setInMenuBar("a", false) } == one)
        #expect(try edit(one) { try $0.setInMenuBar("c", false) } == none)
    }

    @Test func menuBarKeepsComments() throws {
        let text = """
        {
          "menuBar": [
            "a", // first
            "c",
          ],
          "panels": [{ "panel": "a" }, { "panel": "b" }, { "panel": "c" }],
        }
        """
        #expect(try edit(text) { try $0.setInMenuBar("b", true) } == """
        {
          "menuBar": [
            "a", // first
            "b",
            "c",
          ],
          "panels": [{ "panel": "a" }, { "panel": "b" }, { "panel": "c" }],
        }
        """)
    }

    // MARK: Shortcuts

    @Test func keyNames() throws {
        #expect(Shortcut.name(forKeyCode: 49) == "Space")
        #expect(Shortcut.name(forKeyCode: 5) == "G")
        #expect(Shortcut.name(forKeyCode: 96) == "F5")
        #expect(Shortcut.name(forKeyCode: 200) == nil)
        #expect(try Shortcut.parse("⌃⌥" + Shortcut.name(forKeyCode: 5)!).get().keyCode == 5)
        #expect(try Shortcut.parse("⌃⌥" + Shortcut.name(forKeyCode: 123)!).get().keyCode == 123)
    }

    @Test func panelDetails() throws {
        let tile = try ConfigLoader.panel("ci", in: ConfigFixture([
            "panels/ci/panel.jsonc": #"{ "type": "cli", "command": "ls", "description": "Builds", "author": "me", "version": "1.2" }"#,
        ]).directory).get()
        #expect(tile.description == "Builds")
        #expect(tile.author == "me")
        #expect(tile.version == "1.2")
    }
}
