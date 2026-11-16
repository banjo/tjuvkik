import Foundation
import Testing
@testable import TjuvkikCore

struct KeyValueContentTests {
    private func keyvalue(_ text: String) throws -> KeyValueContent {
        guard case .keyvalue(let content) = try ScriptOutput.content(Data(text.utf8), as: .keyvalue).get() else {
            throw ScriptOutputError(message: "not keyvalue")
        }
        return content
    }

    private func pair(_ key: String) -> KeyValueContent.Pair {
        KeyValueContent.Pair(key: key, value: key.lowercased())
    }

    private func entries(_ text: String) -> [KeyValueContent.Entry] {
        text.split(separator: " ").map { word -> KeyValueContent.Entry in
            word.hasPrefix("#") ? .section(String(word.dropFirst())) : .pair(pair(String(word)))
        }
    }

    @Test func everyField() throws {
        let content = try keyvalue(#"""
        { "pairs": [
            { "section": "Kubernetes" },
            { "key": "Context", "value": "aks-prod-weu", "tone": "error", "pill": true },
            { "key": "Namespace", "value": "logbook" } ] }
        """#)
        #expect(content.entries == [
            .section("Kubernetes"),
            .pair(.init(key: "Context", value: "aks-prod-weu", tone: .error, pill: true)),
            .pair(.init(key: "Namespace", value: "logbook")),
        ])
        #expect(content.pairs.map(\.key) == ["Context", "Namespace"])
    }

    @Test func theTopLevelKeyPicksKeyValue() throws {
        let content = try ScriptOutput.content(Data(#"{ "pairs": [{ "key": "a", "value": "b" }] }"#.utf8)).get()
        #expect(content.type == .keyvalue)
    }

    @Test func numbersAndBooleansReadAsText() throws {
        let content = try keyvalue(#"{ "pairs": [{ "key": "Pods", "value": 6 }, { "key": "Load", "value": 0.25 }, { "key": "Up", "value": true }, { "key": 2026, "value": "year" }] }"#)
        #expect(content.pairs.map(\.value) == ["6", "0.25", "true", "year"])
        #expect(content.pairs[3].key == "2026")
    }

    @Test func unknownTonesAndBadPillsAreLenient() throws {
        let content = try keyvalue(#"{ "pairs": [{ "key": "a", "value": "b", "tone": "sparkly", "pill": "yes" }] }"#)
        #expect(content.pairs == [.init(key: "a", value: "b", tone: .normal, pill: false)])
    }

    @Test func onePairWithoutAnArray() throws {
        #expect(try keyvalue(#"{ "pairs": { "key": "a", "value": "b" } }"#).pairs == [.init(key: "a", value: "b")])
    }

    @Test func keyAndValueAreRequired() {
        #expect(ScriptOutput.content(Data(#"{ "pairs": [{ "value": "b" }] }"#.utf8)).failureMessage == #"missing "key" in pairs[0]"#)
        #expect(ScriptOutput.content(Data(#"{ "pairs": [{ "section": "x" }, { "key": "a" }] }"#.utf8)).failureMessage == #"missing "value" in pairs[1]"#)
    }

    @Test func summaryAndMenuBarWork() throws {
        let content = try ScriptOutput.content(Data(#"{ "pairs": [{ "key": "a", "value": "b" }], "summary": [{ "icon": "☸", "value": "prod" }] }"#.utf8)).get()
        #expect(content.menuBar?.title == "☸ prod")
    }

    @Test func sectionsGroupPairsUnderHeadings() {
        let content = KeyValueContent(entries: entries("A #K B C #Empty #R D"))
        #expect(content.sections == [
            .init(pairs: [pair("A")]),
            .init(title: "K", pairs: [pair("B"), pair("C")]),
            .init(title: "R", pairs: [pair("D")]),
        ])
    }

    @Test func emptyHeadingsAreDropped() {
        #expect(KeyValueContent(entries: entries("#A #B")).sections == [])
        #expect(KeyValueContent(entries: []).sections == [])
    }

    @Test func columnsSplitInHalfWithTheExtraLineLeft() {
        let columns = KeyValueContent(entries: entries("A B C D E")).columns
        #expect(columns.left == [.init(pairs: [pair("A"), pair("B"), pair("C")])])
        #expect(columns.right == [.init(pairs: [pair("D"), pair("E")])])
    }

    @Test func aHeadingNeverEndsTheLeftColumn() {
        let columns = KeyValueContent(entries: entries("A B #K C D")).columns
        #expect(columns.left == [.init(pairs: [pair("A"), pair("B")])])
        #expect(columns.right == [.init(title: "K", pairs: [pair("C"), pair("D")])])
    }

    @Test func aSectionCutInTwoGoesOnWithoutItsHeading() {
        let columns = KeyValueContent(entries: entries("#K A B C D")).columns
        #expect(columns.left == [.init(title: "K", pairs: [pair("A"), pair("B")])])
        #expect(columns.right == [.init(pairs: [pair("C"), pair("D")])])
    }

    @Test func aHeadingIsNeverLastInTheLeftColumn() {
        let columns = KeyValueContent(entries: entries("A #K B")).columns
        #expect(columns.left == [.init(pairs: [pair("A")])])
        #expect(columns.right == [.init(title: "K", pairs: [pair("B")])])
    }

    @Test func fewPairsFillTheLeftColumn() {
        #expect(KeyValueContent(entries: entries("A")).columns.left == [.init(pairs: [pair("A")])])
        #expect(KeyValueContent(entries: entries("A")).columns.right == [])
        #expect(KeyValueContent(entries: []).columns.left == [])
    }
}
