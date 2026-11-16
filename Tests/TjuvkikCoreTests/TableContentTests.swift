import Foundation
import Testing
@testable import TjuvkikCore

struct TableContentTests {
    private func table(_ text: String) throws -> TableContent {
        guard case .table(let table) = try ScriptOutput.content(Data(text.utf8), as: .table).get() else {
            throw ScriptOutputError(message: "not a table")
        }
        return table
    }

    @Test func everyField() throws {
        let content = try table(#"""
        { "columns": [{ "title": "Pod", "mono": true, "width": "38%" }, { "title": "Status", "priority": 2 }, { "title": "Restarts", "align": "right" }, { "title": "Age", "align": "center" }],
          "rows": [{ "cells": ["export-1794", { "text": "CrashLoop", "tone": "error", "dot": true }, "12", { "text": "41m", "dim": true }],
                     "highlight": true, "url": "https://example.com", "command": "kubectl logs export-1794" }] }
        """#)
        #expect(content.columns == [
            .init(title: "Pod", mono: true, width: 0.38),
            .init(title: "Status", priority: 2),
            .init(title: "Restarts", align: .right),
            .init(title: "Age", align: .center),
        ])
        #expect(content.rows == [.init(
            cells: [.init("export-1794"), .init("CrashLoop", tone: .error, dot: true), .init("12"), .init("41m", dim: true)],
            highlight: .error, url: "https://example.com", command: "kubectl logs export-1794"
        )])
    }

    @Test func columnsPickTheTypeOverRows() throws {
        let content = try ScriptOutput.content(Data(#"{ "columns": ["A"], "rows": [{ "cells": ["a"] }] }"#.utf8)).get()
        #expect(content.type == .table)
        #expect(try ScriptOutput.content(Data(#"{ "rows": [{ "title": "a" }] }"#.utf8)).get().type == nil)
    }

    @Test func cellsAreRequired() {
        #expect(ScriptOutput.content(Data(#"{ "columns": ["A"], "rows": [{ "highlight": true }] }"#.utf8)).failureMessage == #"missing "cells" in rows[0]"#)
    }

    @Test func columnsAreRequiredAsTable() {
        #expect(ScriptOutput.content(Data(#"{ "rows": [] }"#.utf8), as: .table).failureMessage == #"missing "columns""#)
    }

    @Test func numbersAndNullsReadAsText() throws {
        let content = try table(#"{ "columns": [{ "title": 2026 }], "rows": [{ "cells": [12, 0.5, null, { "text": 3 }] }] }"#)
        #expect(content.columns[0].title == "2026")
        #expect(content.rows[0].cells.map(\.text) == ["12", "0.5", "", "3"])
    }

    @Test func shortForms() throws {
        let content = try table(#"{ "columns": "Port", "rows": [["5173"], { "cells": ["3000"] }] }"#)
        #expect(content.columns == [.init(title: "Port")])
        #expect(content.rows.map(\.cells) == [[.init("5173")], [.init("3000")]])
    }

    @Test func rowsCanBeMissing() throws {
        #expect(try table(#"{ "columns": ["A"] }"#).rows.isEmpty)
    }

    @Test func leniency() throws {
        let content = try table(#"""
        { "columns": [{ "align": "middle", "priority": "3", "width": 38 }, { "priority": 99999, "width": "250%" }, { "width": 0.2 }, { "width": "wide" }],
          "rows": [{ "cells": [{ "text": "a", "tone": "purple" }], "highlight": "warning" }, { "cells": [], "highlight": false }] }
        """#)
        #expect(content.columns.map(\.title) == ["", "", "", ""])
        #expect(content.columns[0].align == .left)
        #expect(content.columns.map(\.priority) == [3, 1_000, 0, 0])
        #expect(content.columns.map(\.width) == [0.38, 1, 0.2, nil])
        #expect(content.rows[0].cells[0].tone == .normal)
        #expect(content.rows[0].highlight == .warning)
        #expect(content.rows[1].highlight == nil)
    }

    @Test func shortRowsHaveEmptyCells() throws {
        let row = TableContent.Row(cells: [.init("a")])
        #expect(row.cell(0) == .init("a"))
        #expect(row.cell(3) == .init(""))
    }

    @Test func summaryAndMenuBar() throws {
        let content = try ScriptOutput.content(Data(#"{ "columns": ["A"], "rows": [], "summary": [{ "icon": "⚠️", "value": "1" }] }"#.utf8)).get()
        #expect(content.menuBar?.title == "⚠️ 1")
    }
}

struct TableLayoutTests {
    @Test func dropsFromTheRight() {
        #expect(TableLayout.visibleColumns(priorities: [0, 0, 0, 0], fitting: 4) == [0, 1, 2, 3])
        #expect(TableLayout.visibleColumns(priorities: [0, 0, 0, 0], fitting: 2) == [0, 1])
        #expect(TableLayout.visibleColumns(priorities: [0, 0, 0], fitting: 0) == [])
        #expect(TableLayout.visibleColumns(priorities: [0, 0], fitting: 5) == [0, 1])
        #expect(TableLayout.visibleColumns(priorities: [0, 0], fitting: -1) == [])
    }

    @Test func priorityKeepsAColumnLonger() {
        #expect(TableLayout.visibleColumns(priorities: [0, 0, 0, 1], fitting: 2) == [0, 3])
        #expect(TableLayout.visibleColumns(priorities: [0, 2, 0, 1], fitting: 2) == [1, 3])
        #expect(TableLayout.visibleColumns(priorities: [0, 2, 0, 1], fitting: 3) == [0, 1, 3])
        #expect(TableLayout.visibleColumns(priorities: [-1, 0, 0], fitting: 2) == [1, 2])
    }

    @Test func fittingCount() {
        let widths: [Double] = [60, 50, 40, 40]
        #expect(TableLayout.fittingCount(widths: widths, priorities: [0, 0, 0, 0], available: 300, spacing: 10) == 4)
        #expect(TableLayout.fittingCount(widths: widths, priorities: [0, 0, 0, 0], available: 180, spacing: 10) == 3)
        #expect(TableLayout.fittingCount(widths: widths, priorities: [0, 0, 0, 0], available: 120, spacing: 10) == 2)
        #expect(TableLayout.fittingCount(widths: widths, priorities: [0, 0, 0, 0], available: 300, spacing: 10, limit: 2) == 2)
        // The kept columns' widths count, not the leftmost ones'.
        #expect(TableLayout.fittingCount(widths: [100, 100, 20], priorities: [1, 0, 1], available: 130, spacing: 10) == 2)
    }

    @Test func fittingCountKeepsOne() {
        #expect(TableLayout.fittingCount(widths: [500], priorities: [0], available: 100, spacing: 10) == 1)
        #expect(TableLayout.fittingCount(widths: [], priorities: [], available: 100, spacing: 10) == 0)
        #expect(TableLayout.fittingCount(widths: [10, 10], priorities: [0], available: 100, spacing: 0) == 1)
    }

    private func widths(_ shares: [Double?], _ available: Double = 100) -> [Double] {
        TableLayout.widths(shares: shares, available: available).map { ($0 * 1_000).rounded() / 1_000 }
    }

    @Test func sharesAndTheRest() {
        #expect(widths([0.4, nil, nil]) == [40, 30, 30])
        #expect(widths([nil, nil]) == [50, 50])
        #expect(widths([]) == [])
        #expect(widths([0.5], 0) == [0])
    }

    @Test func sharesAloneFillTheWidth() {
        #expect(widths([0.3, 0.2]) == [60, 40])
        #expect(widths([0.8, 0.8]) == [50, 50])
    }

    @Test func sharesLeaveRoomForTheRest() {
        #expect(widths([0.9, 0.6, nil]) == [54, 36, 10])
    }
}
