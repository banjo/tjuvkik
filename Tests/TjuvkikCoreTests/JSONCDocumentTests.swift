import Foundation
import Testing
@testable import TjuvkikCore

struct JSONCDocumentTests {
    @Test func setReplacesOnlyTheValue() throws {
        var document = try JSONCDocument("""
        {
          // Themes
          "theme": "dark-glass", // the theme
          "view": "bento",
        }
        """)
        try document.set(.string("dracula"), at: ["theme"])
        #expect(document.text == """
        {
          // Themes
          "theme": "dracula", // the theme
          "view": "bento",
        }
        """)
    }

    @Test func setAddsAKeyWithATrailingComma() throws {
        var document = try JSONCDocument("""
        {
          "view": "bento",
          "layout": "framed",
        }
        """)
        try document.set(.string("dracula"), at: ["theme"])
        #expect(document.text == """
        {
          "view": "bento",
          "layout": "framed",
          "theme": "dracula",
        }
        """)
    }

    @Test func setAddsAKeyWithoutTrailingCommas() throws {
        var document = try JSONCDocument("""
        {
          "view": "bento",
          "layout": "framed" // as is
        }
        """)
        try document.set(.bool(false), at: ["launchAtLogin"])
        #expect(document.text == """
        {
          "view": "bento",
          "layout": "framed", // as is
          "launchAtLogin": false
        }
        """)
    }

    @Test func setAddsAKeyToAnInlineObject() throws {
        var document = try JSONCDocument("""
        {
          "trigger": { "key": "fn" },
        }
        """)
        try document.set(.bool(false), at: ["trigger", "kind"])
        #expect(document.text == """
        {
          "trigger": { "key": "fn", "kind": false },
        }
        """)
    }

    @Test func setCreatesMissingObjects() throws {
        var document = try JSONCDocument("""
        {
          "view": "bento",
        }
        """)
        try document.set(.bool(false), at: ["notifications", "sound"])
        #expect(document.text == """
        {
          "view": "bento",
          "notifications": { "sound": false },
        }
        """)
    }

    @Test func setInAnEmptyObject() throws {
        var inline = try JSONCDocument(#"{ "trigger": {} }"#)
        try inline.set(.number(300), at: ["trigger", "holdMs"])
        #expect(inline.text == #"{ "trigger": { "holdMs": 300 } }"#)

        var multiLine = try JSONCDocument("""
        {
          "panels": [
          ],
        }
        """)
        try multiLine.insert(.object([("panel", .string("cpu")), ("size", .string("m"))]), into: ["panels"], at: 0)
        #expect(multiLine.text == """
        {
          "panels": [
            { "panel": "cpu", "size": "m" }
          ],
        }
        """)
    }

    @Test func removeTakesTheLineWithItsComment() throws {
        var document = try JSONCDocument("""
        {
          "panels": [
            { "panel": "agents" },
            // CI for the app
            { "panel": "ci" }, // note
            { "panel": "disk" },
          ],
        }
        """)
        try document.remove(at: ["panels", 1])
        #expect(document.text == """
        {
          "panels": [
            { "panel": "agents" },
            // CI for the app
            { "panel": "disk" },
          ],
        }
        """)
    }

    @Test func removeTheLastMemberOfAnInlineObject() throws {
        var document = try JSONCDocument(#"{ "a": 1, "b": 2 }"#)
        try document.remove(at: ["b"])
        #expect(document.text == #"{ "a": 1 }"#)
        try document.remove(at: ["a"])
        #expect(document.text == "{}")
    }

    @Test func removeTheFirstMemberOfAnInlineObject() throws {
        var document = try JSONCDocument(#"{ "trigger": { "key": "rightOption", "mode": "toggle" } }"#)
        try document.remove(at: ["trigger", "key"])
        #expect(document.text == #"{ "trigger": { "mode": "toggle" } }"#)
    }

    @Test func removeTheLastLineTakesTheCommaBeforeIt() throws {
        var document = try JSONCDocument("""
        {
          "view": "bento",
          "theme": "dracula"
        }
        """)
        try document.remove(at: ["theme"])
        #expect(document.text == """
        {
          "view": "bento"
        }
        """)
    }

    @Test func removeAMissingKey() throws {
        let text = """
        {
          "view": "bento", // comment
        }
        """
        var document = try JSONCDocument(text)
        try document.remove(at: ["theme"])
        try document.remove(at: ["view", "nope"])
        try document.remove(at: ["panels", 3])
        #expect(document.text == text)
    }

    @Test func insertAppends() throws {
        var document = try JSONCDocument("""
        {
          "panels": [
            { "panel": "agents" },
            { "panel": "ci" },
            { "panel": "disk" }, // last
          ],
        }
        """)
        try document.insert(.object([("panel", .string("cpu"))]), into: ["panels"], at: 3)
        #expect(document.text == """
        {
          "panels": [
            { "panel": "agents" },
            { "panel": "ci" },
            { "panel": "disk" }, // last
            { "panel": "cpu" },
          ],
        }
        """)
    }

    @Test func insertAtTheStart() throws {
        var document = try JSONCDocument("""
        {
          "panels": [
            { "panel": "agents" },
            { "panel": "ci" }
          ]
        }
        """)
        try document.insert(.object([("panel", .string("cpu"))]), into: ["panels"], at: 0)
        #expect(document.text == """
        {
          "panels": [
            { "panel": "cpu" },
            { "panel": "agents" },
            { "panel": "ci" }
          ]
        }
        """)
    }

    @Test func insertIntoAnInlineArray() throws {
        var document = try JSONCDocument(#"{ "menuBar": ["a", "c"] }"#)
        try document.insert(.string("b"), into: ["menuBar"], at: 1)
        try document.insert(.string("d"), into: ["menuBar"], at: 3)
        #expect(document.text == #"{ "menuBar": ["a", "b", "c", "d"] }"#)
    }

    @Test func insertCreatesTheArray() throws {
        var document = try JSONCDocument("{}")
        try document.insert(.string("a"), into: ["menuBar"], at: 0)
        #expect(document.text == #"{ "menuBar": ["a"] }"#)
    }

    @Test func moveKeepsTheComment() throws {
        var document = try JSONCDocument("""
        {
          "panels": [
            { "panel": "agents" }, // comment
            { "panel": "ci" },
            { "panel": "disk" },
          ],
        }
        """)
        try document.move(in: ["panels"], from: 0, to: 2)
        #expect(document.text == """
        {
          "panels": [
            { "panel": "ci" },
            { "panel": "disk" },
            { "panel": "agents" }, // comment
          ],
        }
        """)
        try document.move(in: ["panels"], from: 2, to: 0)
        #expect(document.text == """
        {
          "panels": [
            { "panel": "agents" }, // comment
            { "panel": "ci" },
            { "panel": "disk" },
          ],
        }
        """)
    }

    @Test func moveWithoutTrailingCommas() throws {
        var document = try JSONCDocument("""
        [
          1,
          2,
          3
        ]
        """)
        try document.move(in: [], from: 2, to: 0)
        #expect(document.text == """
        [
          3,
          1,
          2
        ]
        """)
        try document.move(in: [], from: 0, to: 2)
        #expect(document.text == """
        [
          1,
          2,
          3
        ]
        """)
    }

    @Test func reading() throws {
        let document = try JSONCDocument("""
        {
          "panels": [
            { "panel": "agents", "size": "m" },
            { "panel": "ci" },
            { "panel": "disk" },
          ],
        }
        """)
        #expect(document.value(String.self, at: ["panels", 0, "panel"]) == "agents")
        #expect(document.value(Int.self, at: ["nope"]) == nil)
        #expect(document.value(Int.self, at: ["panels", 0, "panel"]) == nil)
        #expect(document.count(at: ["panels"]) == 3)
        #expect(document.count(at: ["panels", 0]) == 0)
    }

    @Test func json5() throws {
        var document = try JSONCDocument("""
        {
          /* block
             comment */
          theme: 'dark-glass',
          'view': "bento",
          $schema: "x",
          n: +1.5e3,
        }
        """)
        #expect(document.value(String.self, at: ["theme"]) == "dark-glass")
        #expect(document.value(String.self, at: ["view"]) == "bento")
        try document.set(.string("dracula"), at: ["theme"])
        #expect(document.text == """
        {
          /* block
             comment */
          theme: "dracula",
          'view': "bento",
          $schema: "x",
          n: +1.5e3,
        }
        """)
    }

    @Test func writingValues() {
        #expect(JSONCDocument.render(.number(5)) == "5")
        #expect(JSONCDocument.render(.number(2.5)) == "2.5")
        #expect(JSONCDocument.render(.string("a \"b\"\n\\")) == #""a \"b\"\n\\""#)
        #expect(JSONCDocument.render(.array([])) == "[]")
        #expect(JSONCDocument.render(.object([])) == "{}")
        #expect(JSONCDocument.render(.object([("a", .null), ("b", .array([.bool(true), .number(1)]))])) == #"{ "a": null, "b": [true, 1] }"#)
    }

    @Test func errors() {
        #expect(throws: JSONCDocument.ParseError(line: 1, column: 9, message: #"expected "," or "}""#)) { try JSONCDocument(#"{ "a": 1"#) }
        #expect(throws: JSONCDocument.ParseError(line: 1, column: 8, message: "unterminated string")) { try JSONCDocument(#"{ "a": "x }"#) }
        #expect(throws: JSONCDocument.ParseError(line: 2, column: 7, message: #"expected ":""#)) { try JSONCDocument("{\n  \"a\" 1 }") }
        #expect(throws: JSONCDocument.ParseError(line: 1, column: 3, message: "unterminated comment")) { try JSONCDocument("{ /* x }") }
        #expect(throws: JSONCDocument.ParseError(line: 1, column: 6, message: #"expected "," or "]""#)) { try JSONCDocument("[1, 2") }
        #expect(throws: JSONCDocument.ParseError(line: 1, column: 4, message: "unexpected text after the value")) { try JSONCDocument("{} x") }
        #expect(throws: JSONCDocument.ParseError(line: 1, column: 1, message: "expected a value")) { try JSONCDocument("") }
    }

    @Test func defaultConfigRoundTrip() throws {
        var document = try JSONCDocument(DefaultConfig.config)
        try document.set(.string("dark-glass"), at: ["theme"])
        try document.set(.object([("key", .string("fn")), ("holdMs", .number(250))]), at: ["trigger"])
        try document.set(.bool(true), at: ["launchAtLogin"])
        try document.set(.object([("panel", .string("disk"))]), at: ["panels", 0])
        #expect(document.text == DefaultConfig.config)
    }
}
