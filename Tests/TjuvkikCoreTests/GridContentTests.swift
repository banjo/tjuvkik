import Foundation
import Testing
@testable import TjuvkikCore

struct GridContentTests {
    private func grid(_ text: String) throws -> GridContent {
        guard case .grid(let grid) = try ScriptOutput.content(Data(text.utf8), as: .grid).get() else {
            throw ScriptOutputError(message: "not a grid")
        }
        return grid
    }

    private func rows(_ tones: [Tone], legend: String = "") throws -> GridContent {
        let rows = tones.enumerated().map { #"{ "label": "r\#($0.offset)", "tone": "\#($0.element.rawValue)" }"# }.joined(separator: ", ")
        return try grid(#"{ "grid": { "rows": [\#(rows)]\#(legend.isEmpty ? "" : ", \"legend\": \(legend)") } }"#)
    }

    @Test func everyField() throws {
        let content = try grid(#"""
        { "grid": {
            "rows": [{ "label": "assets-api", "value": "99.2%", "tone": "warning", "cells": ["success", "warning", null] }],
            "axis": ["24h ago", "12h", "now"],
            "legend": { "error": "down", "success": "up", "warning": "degraded" },
            "footer": "checked every 5m", "value": "1 slow", "label": "of 7", "tone": "info" } }
        """#)
        #expect(content.rows == [.init(label: "assets-api", value: "99.2%", tone: .warning, cells: [.tone(.success), .tone(.warning), .tone(.normal)])])
        #expect(content.axis == ["24h ago", "12h", "now"])
        #expect(content.legend == [.init(tone: .success, text: "up"), .init(tone: .warning, text: "degraded"), .init(tone: .error, text: "down")])
        #expect(content.footer == "checked every 5m")
        #expect(content.headline == .init(value: "1 slow", label: "of 7", tone: .info))
        #expect(content.levels == nil)
    }

    @Test func theGridKeyPicksTheType() throws {
        let content = try ScriptOutput.content(Data(#"{ "grid": { "rows": [{ "label": "a" }] } }"#.utf8)).get()
        #expect(content.type == .grid)
        // Top-level rows are still rows, not a grid.
        #expect(try ScriptOutput.content(Data(#"{ "rows": [{ "title": "a" }] }"#.utf8)).get().type == nil)
    }

    @Test func labelIsRequired() {
        #expect(ScriptOutput.content(Data(#"{ "grid": { "rows": [{ "value": "1" }] } }"#.utf8)).failureMessage == #"missing "label" in grid.rows[0]"#)
    }

    @Test func gridNeedsRowsOrLevels() {
        #expect(ScriptOutput.content(Data(#"{ "grid": { "axis": ["now"] } }"#.utf8)).failureMessage == #"missing "rows" in grid"#)
        #expect(ScriptOutput.content(Data(#"{ "rows": [] }"#.utf8), as: .grid).failureMessage == #"missing "grid""#)
    }

    @Test func numbersReadAsText() throws {
        let content = try grid(#"{ "grid": { "rows": [{ "label": 404, "value": 99.5 }], "footer": 3 } }"#)
        #expect(content.rows[0].label == "404")
        #expect(content.rows[0].value == "99.5")
        #expect(content.footer == "3")
    }

    @Test func oneRowWithoutAnArray() throws {
        #expect(try grid(#"{ "grid": { "rows": { "label": "a" } } }"#).rows == [.init(label: "a")])
    }

    @Test func numberCellsAreLevelsClamped() throws {
        let content = try grid(#"{ "grid": { "rows": [{ "label": "a", "cells": [0, 2.6, 9, -1, "3", "nope"] }] } }"#)
        #expect(content.rows[0].cells == [.level(0), .level(3), .level(4), .level(0), .level(3), .tone(.normal)])
    }

    @Test func unknownLegendKeysAreLeftOut() throws {
        let content = try grid(#"{ "grid": { "rows": [], "legend": { "success": "up", "sideways": "?" } } }"#)
        #expect(content.legend == [.init(tone: .success, text: "up")])
    }

    @Test func statusIsTheToneElseTheLastToneCell() {
        #expect(GridContent.Row(label: "a", tone: .error, cells: [.tone(.success)]).status == .error)
        #expect(GridContent.Row(label: "a", cells: [.tone(.warning), .tone(.success), .level(2)]).status == .success)
        #expect(GridContent.Row(label: "a", cells: [.level(4)]).status == .normal)
    }

    @Test func severityOrder() {
        let order: [Tone] = [.error, .warning, .info, .success, .muted]
        #expect(order.map(GridContent.severity) == [4, 3, 2, 1, 0])
        #expect(GridContent.severity(.accent) == GridContent.severity(.info))
        #expect(GridContent.severity(.normal) == GridContent.severity(.muted))
    }

    @Test func worstAndCounts() throws {
        let content = try rows([.success, .warning, .success, .error, .accent, .info, .muted])
        #expect(content.worst == .error)
        #expect(content.counts == [
            .init(tone: .error, count: 1), .init(tone: .warning, count: 1), .init(tone: .accent, count: 1),
            .init(tone: .info, count: 1), .init(tone: .success, count: 2), .init(tone: .muted, count: 1),
        ])
        #expect(try rows([]).worst == nil)
        #expect(try rows([.info, .accent]).worst == .info)
    }

    @Test func headlineCountsTheWorst() throws {
        let legend = #"{ "success": "up", "warning": "degraded", "error": "down" }"#
        let tones: [Tone] = [.success, .success, .success, .warning, .success, .success, .error] + Array(repeating: .success, count: 5)
        #expect(try rows(tones, legend: legend).headline == .init(value: "1 down", label: "1 degraded, 10 up", tone: .error))
        #expect(try rows([.success, .success], legend: legend).headline == .init(value: "All up", tone: .success))
        #expect(try rows([.warning, .warning, .success]).headline == .init(value: "2 warning", label: "1 ok", tone: .warning))
        #expect(try rows([.normal, .normal]).headline == .init(value: "2", tone: .normal))
        #expect(try rows([]).headline == .init(value: "0", tone: .normal))
    }

    @Test func flatLevelsFillColumnsOfSeven() throws {
        let content = try grid(#"{ "grid": { "levels": [0, 1, 2, 3, 4, 5, 6, 1, 2] } }"#)
        #expect(content.rows.isEmpty)
        #expect(content.levels == [[0, 1, 2, 3, 4, 4, 4], [1, 2]])
        #expect(content.levelHeight == 7)
        #expect(try grid(#"{ "grid": { "levels": [1, 2, 3, 4], "height": 2 } }"#).levels == [[1, 2], [3, 4]])
    }

    @Test func levelsAsColumns() throws {
        let content = try grid(#"{ "grid": { "levels": [[0, 1], ["2", 3.4, null]], "tone": "success" } }"#)
        #expect(content.levels == [[0, 1], [2, 3, 0]])
        #expect(content.levelHeight == 3)
        #expect(content.tone == .success)
    }

    @Test func heatmapKeepsTheNewestColumns() {
        let content = GridContent(levels: [[1], [2], [3]])
        #expect(content.heatmap(limit: 2) == [[2], [3]])
        #expect(content.heatmap() == [[1], [2], [3]])
        #expect(GridContent(rows: []).heatmap(limit: 2) == [])
    }

    @Test func levelOpacity() {
        #expect(GridContent.opacity(level: 0) == 0.06)
        #expect(abs(GridContent.opacity(level: 4) - 0.98) < 0.0001)
        #expect(GridContent.opacity(level: 9) == GridContent.opacity(level: 4))
    }

    @Test func summaryAndMenuBarWork() throws {
        let content = try ScriptOutput.content(Data(#"{ "grid": { "rows": [] }, "summary": [{ "icon": "🟢", "value": "12" }] }"#.utf8)).get()
        #expect(content.menuBar?.title == "🟢 12")
    }
}
