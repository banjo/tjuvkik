import Foundation
import Testing
@testable import TjuvkikCore

struct MarkdownContentTests {
    private func content(_ text: String, as type: ContentType? = nil) -> Result<ModuleContent, ScriptOutputError> {
        ScriptOutput.content(Data(text.utf8), as: type)
    }

    private func markdown(_ text: String) throws -> MarkdownContent {
        guard case .markdown(let markdown) = try content(text, as: .markdown).get() else {
            throw ScriptOutputError(message: "not markdown")
        }
        return markdown
    }

    @Test func detectedByItsKey() throws {
        #expect(try content(##"{ "markdown": "# Hi" }"##).get().type == .markdown)
        #expect(try content(##"{ "rows": [] }"##).get().type == nil)
    }

    @Test func parsesTheOutput() throws {
        let content = try markdown(####"{ "markdown": "### On call\n**Anton** until Fri", "summary": [{ "icon": "📟", "value": "Anton" }] }"####)
        #expect(content.markdown == "### On call\n**Anton** until Fri")
        #expect(content.blocks == [.heading(level: 3, text: "On call"), .paragraph("**Anton** until Fri")])
        #expect(content.extras.summary?.first?.value == "Anton")
        #expect(content.extras.menuBar?.title == "📟 Anton")
    }

    @Test func linesCanBeAnArray() throws {
        let content = try markdown(##"{ "markdown": ["# A", "text"] }"##)
        #expect(content.markdown == "# A\ntext")
        #expect(content.blocks == [.heading(level: 1, text: "A"), .paragraph("text")])
    }

    @Test func errors() {
        #expect(content(##"{ "rows": [] }"##, as: .markdown).failureMessage == #"missing "markdown""#)
        #expect(content(##"{ "markdown": 3 }"##).failureMessage == "wrong type at markdown")
    }

    @Test func emptyTextHasNoBlocks() {
        #expect(MarkdownContent(markdown: "").blocks.isEmpty)
        #expect(MarkdownContent(markdown: "\n  \n").blocks.isEmpty)
    }

    @Test func titleLevelIsTheHighestOfTheFirstThree() {
        #expect(MarkdownContent(markdown: "### On call\n#### Restart").titleLevel == 3)
        #expect(MarkdownContent(markdown: "# T\n## S\n### S2").titleLevel == 1)
        #expect(MarkdownContent(markdown: "#### New\n#### Fixed").titleLevel == nil)
        #expect(MarkdownContent(markdown: "Just text").titleLevel == nil)
    }
}

struct MarkdownParserTests {
    private func parse(_ text: String) -> [MarkdownBlock] {
        MarkdownParser.parse(text)
    }

    private func item(_ text: String, _ marker: MarkdownListItem.Marker = .bullet, depth: Int = 0, checked: Bool? = nil) -> MarkdownListItem {
        MarkdownListItem(marker: marker, depth: depth, checked: checked, text: text)
    }

    @Test func headings() {
        #expect(parse("# One\n## Two ##\n###### Six\n####### Seven\n#NoSpace\n#") == [
            .heading(level: 1, text: "One"),
            .heading(level: 2, text: "Two"),
            .heading(level: 6, text: "Six"),
            .paragraph("####### Seven #NoSpace"),
            .heading(level: 1, text: ""),
        ])
        #expect(parse("## C# is fine") == [.heading(level: 2, text: "C# is fine")])
        #expect(parse("   ### Indented") == [.heading(level: 3, text: "Indented")])
    }

    @Test func paragraphsJoinSoftBreaksAndKeepHardOnes() {
        #expect(parse("First line\nsecond line\n\nNew paragraph  \nwith a break\\\nand another") == [
            .paragraph("First line second line"),
            .paragraph("New paragraph\nwith a break\nand another"),
        ])
        #expect(parse("  indented text  ") == [.paragraph("indented text")])
    }

    @Test func bulletLists() {
        #expect(parse("- one\n* two\n+ three") == [.list([item("one"), item("two"), item("three")])])
        #expect(parse("-not a list\n*emphasis*") == [.paragraph("-not a list *emphasis*")])
    }

    @Test func numberedListsCountOn() {
        #expect(parse("1. one\n1. two\n5) three") == [.list([item("one", .number(1)), item("two", .number(2)), item("three", .number(3))])])
        #expect(parse("3. c\n4. d") == [.list([item("c", .number(3)), item("d", .number(4))])])
        #expect(parse("1. a\n- b\n1. c") == [.list([item("a", .number(1)), item("b"), item("c", .number(1))])])
    }

    @Test func nestedLists() {
        #expect(parse("- a\n  - b\n    1. c\n  - d\n- e") == [.list([
            item("a"), item("b", depth: 1), item("c", .number(1), depth: 2), item("d", depth: 1), item("e"),
        ])])
    }

    @Test func nestingStopsAtTheMaximumDepth() {
        let blocks = parse("- a\n  - b\n    - c\n      - d\n        - e")
        guard case .list(let items) = blocks.first else {
            Issue.record("not a list")
            return
        }
        #expect(items.map(\.depth) == [0, 1, 2, 3, 3])
    }

    @Test func taskLists() {
        #expect(parse("- [ ] open\n- [x] done\n- [X] Done too\n- [ ]\n- [link](x)\n- [x]not a task\n1. [x] numbered") == [.list([
            item("open", checked: false),
            item("done", checked: true),
            item("Done too", checked: true),
            item("", checked: false),
            item("[link](x)"),
            item("[x]not a task"),
            item("numbered", .number(1), checked: true),
        ])])
    }

    @Test func listItemsContinue() {
        #expect(parse("- one\ncontinues\n- two\n\n  more about two\n\nAfter") == [
            .list([item("one continues"), item("two\nmore about two")]),
            .paragraph("After"),
        ])
        #expect(parse("- a\n\n- b") == [.list([item("a"), item("b")])])
        #expect(parse("- a\n# H") == [.list([item("a")]), .heading(level: 1, text: "H")])
        #expect(parse("Intro\n- a") == [.paragraph("Intro"), .list([item("a")])])
    }

    @Test func fencedCode() {
        #expect(parse("```swift\nlet x = 1\n\n  indented\n```\nafter") == [
            .code(language: "swift", text: "let x = 1\n\n  indented"),
            .paragraph("after"),
        ])
        #expect(parse("```sh title\nls\n```") == [.code(language: "sh", text: "ls")])
    }

    @Test func codeIsntParsed() {
        #expect(parse("~~~\n# not a heading\n- not a list") == [.code(language: nil, text: "# not a heading\n- not a list")])
        #expect(parse("````\n```\n````") == [.code(language: nil, text: "```")])
    }

    @Test func indentedFencesDropTheirIndentation() {
        #expect(parse("  ```\n    two\n  ```") == [.code(language: nil, text: "  two")])
    }

    @Test func inlineCodeIsntAFence() {
        #expect(parse("```code``` here") == [.paragraph("```code``` here")])
    }

    @Test func blockquotes() {
        #expect(parse("> Degraded since 11:20.\nlazy continuation\n> > nested\n\nAfter") == [
            .quote([.paragraph("Degraded since 11:20. lazy continuation"), .quote([.paragraph("nested")])]),
            .paragraph("After"),
        ])
        #expect(parse("> - a\n> - b") == [.quote([.list([item("a"), item("b")])])])
        #expect(parse(">no space") == [.quote([.paragraph("no space")])])
        #expect(parse("> one\n>\n> two") == [.quote([.paragraph("one"), .paragraph("two")])])
    }

    @Test func thematicBreaks() {
        #expect(parse("---\n***\n_ _ _\n- - -\n--") == [.rule, .rule, .rule, .rule, .paragraph("--")])
        // No setext headings: the line under text is a rule.
        #expect(parse("text\n---") == [.paragraph("text"), .rule])
    }

    @Test func windowsLineEndingsAndTabs() {
        #expect(parse("# A\r\n-\tb\r\n\t- c") == [.heading(level: 1, text: "A"), .list([item("b"), item("c", depth: 1)])])
    }

    @Test func aRealDocument() {
        let text = """
        ### On call this week
        **Anton Ödman** until Fri 17:00, then **Sara Lind**.

        > workshop-hist is degraded since 11:20.

        #### Restart a stuck export
        1. Find the job: `kubectl get jobs -n logbook`
        2. Check its last log lines

        ```
        kubectl delete job export-1794 -n logbook
        ```

        #### Links
        - [Grafana](https://grafana.example.com)
        """
        #expect(parse(text) == [
            .heading(level: 3, text: "On call this week"),
            .paragraph("**Anton Ödman** until Fri 17:00, then **Sara Lind**."),
            .quote([.paragraph("workshop-hist is degraded since 11:20.")]),
            .heading(level: 4, text: "Restart a stuck export"),
            .list([item("Find the job: `kubectl get jobs -n logbook`", .number(1)), item("Check its last log lines", .number(2))]),
            .code(language: nil, text: "kubectl delete job export-1794 -n logbook"),
            .heading(level: 4, text: "Links"),
            .list([item("[Grafana](https://grafana.example.com)")]),
        ])
    }
}

struct MarkdownFlowTests {
    private typealias Piece = MarkdownFlow.Piece
    private typealias Slot = MarkdownFlow.Slot

    @Test func oneColumnCutsWhatDoesntFit() {
        let pieces = [Piece(height: 20), Piece(height: 20, spacing: 5), Piece(height: 20, spacing: 5)]
        #expect(MarkdownFlow.place(pieces, columns: 1, height: 50) == [Slot(column: 0, y: 0, height: 20), Slot(column: 0, y: 25, height: 20), nil])
    }

    @Test func aHeadingIsntLeftAtTheBottom() {
        let pieces = [Piece(height: 20), Piece(height: 10, spacing: 5, keepWithNext: true), Piece(height: 20, spacing: 5)]
        #expect(MarkdownFlow.place(pieces, columns: 1, height: 40) == [Slot(column: 0, y: 0, height: 20), nil, nil])
    }

    @Test func aPieceTallerThanTheColumnIsCutToIt() {
        #expect(MarkdownFlow.place([Piece(height: 100), Piece(height: 10)], columns: 1, height: 50) == [Slot(column: 0, y: 0, height: 50), nil])
    }

    @Test func twoColumnsAreBalancedAndKeepHeadingsWithTheirText() {
        // A title and three items, then a section with a paragraph.
        let pieces = [
            Piece(height: 20, keepWithNext: true), Piece(height: 20), Piece(height: 20), Piece(height: 20),
            Piece(height: 15, spacing: 10, keepWithNext: true), Piece(height: 40),
        ]
        #expect(MarkdownFlow.place(pieces, columns: 2, height: 200) == [
            Slot(column: 0, y: 0, height: 20), Slot(column: 0, y: 20, height: 20), Slot(column: 0, y: 40, height: 20),
            Slot(column: 0, y: 60, height: 20), Slot(column: 1, y: 0, height: 15), Slot(column: 1, y: 15, height: 40),
        ])
        let sections = [Piece(height: 10, keepWithNext: true), Piece(height: 10), Piece(height: 10, keepWithNext: true), Piece(height: 10)]
        #expect(MarkdownFlow.place(sections, columns: 2, height: 100).map { $0?.column } == [0, 0, 1, 1])
    }

    @Test func twoColumnsFillInTurnWhenBalancedDoesntFit() {
        let pieces = Array(repeating: Piece(height: 30), count: 4)
        #expect(MarkdownFlow.place(pieces, columns: 2, height: 50) == [Slot(column: 0, y: 0, height: 30), Slot(column: 1, y: 0, height: 30), nil, nil])
    }

    @Test func onePieceStaysInTheFirstColumn() {
        #expect(MarkdownFlow.place([Piece(height: 10)], columns: 2, height: 50) == [Slot(column: 0, y: 0, height: 10)])
        #expect(MarkdownFlow.place([], columns: 2, height: 50).isEmpty)
    }
}
