import Foundation
import Testing
@testable import TjuvkikCore

struct MetersContentTests {
    private func meters(_ text: String) throws -> MetersContent {
        guard case .meters(let meters) = try ScriptOutput.content(Data(text.utf8), as: .meters).get() else {
            throw ScriptOutputError(message: "not meters")
        }
        return meters
    }

    @Test func everyField() throws {
        let content = try meters(#"""
            { "meters": [{ "label": "Macintosh HD", "value": 412, "max": 494, "text": "412 GB", "of": "494 GB", "mark": 450, "tone": "warning" }],
              "footer": "82 GB free · Time Machine 2h ago" }
            """#)
        #expect(content.meters == [.init(label: "Macintosh HD", value: 412, max: 494, text: "412 GB", of: "494 GB", mark: 450, tone: .warning)])
        #expect(content.footer == "82 GB free · Time Machine 2h ago")
    }

    @Test func theTopLevelKeyPicksMeters() throws {
        let content = try ScriptOutput.content(Data(#"{ "meters": [{ "value": 40 }] }"#.utf8)).get()
        #expect(content.type == .meters)
    }

    @Test func withoutMaxTheValueIsAPercentage() throws {
        let meter = try meters(#"{ "meters": [{ "label": "CPU", "value": 71 }] }"#).meters[0]
        #expect(meter.max == 100)
        #expect(meter.text == "71%")
        #expect(meter.of == nil)
        #expect(meter.fraction == 0.71)
    }

    @Test func withMaxTheNumbersAreTheText() throws {
        let meter = try meters(#"{ "meters": [{ "value": 21, "max": 34 }] }"#).meters[0]
        #expect(meter.text == "21")
        #expect(meter.of == "34")
    }

    @Test func numbersAsText() throws {
        let meter = try meters(#"{ "meters": [{ "label": 3, "value": "4,212", "max": "5000", "mark": " 90% ", "text": 4212, "of": 5000 }] }"#).meters[0]
        #expect(meter.label == "3")
        #expect(meter.value == 4212)
        #expect(meter.max == 5000)
        #expect(meter.mark == 90)
        #expect(meter.text == "4212")
        #expect(meter.of == "5000")
    }

    @Test func oneMeterWithoutAnArray() throws {
        #expect(try meters(#"{ "meters": { "value": 3 } }"#).meters == [.init(value: 3)])
    }

    @Test func valueIsRequired() {
        #expect(ScriptOutput.content(Data(#"{ "meters": [{ "label": "x" }] }"#.utf8)).failureMessage == #"missing "value" in meters[0]"#)
    }

    @Test func valueMustBeANumber() {
        #expect(ScriptOutput.content(Data(#"{ "meters": [{ "value": "lots" }] }"#.utf8)).failureMessage == "wrong type at meters[0].value")
    }

    @Test func thePanelsTypeSaysWhatsMissing() {
        #expect(ScriptOutput.content(Data(#"{ "rows": [] }"#.utf8), as: .meters).failureMessage == #"missing "meters""#)
    }

    @Test func fractionIsClamped() {
        #expect(MetersContent.Meter(value: 50, max: 200).fraction == 0.25)
        #expect(MetersContent.Meter(value: 120).fraction == 1)
        #expect(MetersContent.Meter(value: -5).fraction == 0)
        #expect(MetersContent.Meter(value: 5, max: 0).fraction == 0)
        #expect(MetersContent.Meter(value: 5, max: -10).fraction == 0)
        #expect(MetersContent.Meter(value: .nan).fraction == 0)
        #expect(MetersContent.Meter(value: .infinity).fraction == 0)
    }

    @Test func markFraction() {
        #expect(MetersContent.Meter(value: 412, max: 494).markFraction == nil)
        #expect(MetersContent.Meter(value: 1, max: 200, mark: 150).markFraction == 0.75)
        #expect(MetersContent.Meter(value: 1, mark: 140).markFraction == 1)
        #expect(MetersContent.Meter(value: 1, mark: -3).markFraction == 0)
    }

    @Test func summaryAndMenuBarWork() throws {
        let content = try ScriptOutput.content(Data(#"{ "meters": [{ "value": 1 }], "summary": [{ "icon": "💾", "value": "82 GB" }] }"#.utf8)).get()
        #expect(content.menuBar?.title == "💾 82 GB")
    }
}
