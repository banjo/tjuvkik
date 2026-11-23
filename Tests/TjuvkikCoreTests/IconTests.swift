import Foundation
import Testing
@testable import TjuvkikCore

struct IconTests {
    @Test func readsTextSymbolsAndSpinner() {
        #expect(Icon("👀") == .text("👀"))
        #expect(Icon("sf:hammer.fill") == .symbol("hammer.fill", effect: nil))
        #expect(Icon("sf:gearshape:rotate") == .symbol("gearshape", effect: .rotate))
        #expect(Icon("spinner") == .spinner)
        #expect(Icon(nil) == nil)
        #expect(Icon(" ") == nil)
        #expect(Icon("sf:") == nil)
    }

    @Test func unknownEffectDrawsTheSymbolStill() {
        #expect(Icon("sf:gearshape:spin") == .symbol("gearshape", effect: nil))
        #expect(Icon.problem("sf:gearshape:spin")?.contains("unknown effect \"spin\"") == true)
        #expect(Icon.problem("sf:gearshape:pulse") == nil)
        #expect(Icon.problem("👀") == nil)
    }

    @Test func onlyTextGoesIntoText() {
        #expect(Icon("❓")?.text == "❓")
        #expect(Icon("sf:bell")?.text == nil)
        #expect(Icon("spinner")?.text == nil)
    }

    @Test func automaticMenuLeavesSymbolsOut() throws {
        let content = try ScriptOutput.parse(Data(#"{ "summary": [{ "icon": "sf:bell", "value": "2", "label": "waiting" }, { "icon": "⏳", "value": "1" }], "rows": [] }"#.utf8)).get()
        #expect(content.menuBar?.icon == "sf:bell")
        #expect(content.menuBar?.menu?.map(\.title) == ["2 waiting  ·  ⏳ 1"])
    }

    @Test func collectsEveryIcon() throws {
        let rows = try ScriptOutput.content(Data("""
        { "summary": [{ "icon": "spinner" }], "rows": [{ "icon": "sf:bell", "title": "a" }, { "title": "b" }],
          "menuBar": { "icon": "⇡", "menu": [{ "icon": "sf:x", "title": "c" }] } }
        """.utf8)).get()
        #expect(rows.icons == ["sf:bell", "spinner", "⇡", "sf:x"])
        let feed = try ScriptOutput.content(Data(#"{ "items": [{ "icon": "sf:ant", "text": "hi" }] }"#.utf8)).get()
        #expect(feed.icons == ["sf:ant"])
    }
}
