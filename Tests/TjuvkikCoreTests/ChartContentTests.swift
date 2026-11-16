import Foundation
import Testing
@testable import TjuvkikCore

struct ChartContentTests {
    private func output(_ text: String, as type: ContentType? = .chart) -> Result<ModuleContent, ScriptOutputError> {
        ScriptOutput.content(Data(text.utf8), as: type)
    }

    private func chart(_ text: String) throws -> ChartContent {
        guard case .chart(let chart) = try output(text).get() else { throw ScriptOutputError(message: "not a chart") }
        return chart
    }

    @Test func everyField() throws {
        let content = try chart(#"""
        { "chart": {
            "value": "64", "unit": "%", "label": "CPU, all cores",
            "delta": { "text": "▲ 22 pts in 10m", "tone": "warning" },
            "series": [31, 28, 35, 64],
            "min": 0, "max": 100, "threshold": 80, "axis": ["−60m", "−30m", "now"], "tone": "accent" } }
        """#)
        #expect(content == ChartContent(
            value: "64", unit: "%", label: "CPU, all cores", delta: .init(text: "▲ 22 pts in 10m", tone: .warning),
            series: [31, 28, 35, 64], min: 0, max: 100, threshold: 80, axis: ["−60m", "−30m", "now"], tone: .accent
        ))
    }

    @Test func theChartKeyPicksTheType() throws {
        #expect(try output(#"{ "chart": { "value": 1 } }"#, as: nil).get().type == .chart)
        #expect(try output(#"{ "stats": [{ "value": 1 }] }"#, as: nil).get().type == .stats)
    }

    @Test func summaryAndMenuBarWork() throws {
        let content = try output(#"{ "chart": { "value": 1 }, "summary": [{ "icon": "🔥", "value": "64%" }] }"#, as: nil).get()
        #expect(content.menuBar?.title == "🔥 64%")
    }

    @Test func numbersAndTextBothRead() throws {
        let content = try chart(#"{ "chart": { "value": 0.4, "series": ["0.1", 0.2, null, " 0.3 "], "min": "0", "max": "1", "threshold": "0.5", "axis": [-60, "now"], "delta": 0.3 } }"#)
        #expect(content.value == "0.4")
        #expect(content.series == [0.1, 0.2, 0.3])
        #expect(content.min == 0)
        #expect(content.max == 1)
        #expect(content.threshold == 0.5)
        #expect(content.axis == ["-60", "now"])
        #expect(content.delta == .init(text: "0.3"))
    }

    @Test func deltaCanBeJustText() throws {
        #expect(try chart(#"{ "chart": { "value": 1, "delta": "▲ 3 since Mon" } }"#).delta == .init(text: "▲ 3 since Mon"))
    }

    @Test func oneAxisLabelWithoutAnArray() throws {
        #expect(try chart(#"{ "chart": { "value": 1, "axis": "now" } }"#).axis == ["now"])
    }

    @Test func withoutAValueTheLastPointIsIt() throws {
        let content = try chart(#"{ "chart": { "series": [3, 4, 7] } }"#)
        #expect(content.value == "7")
        #expect(content.series == [3, 4, 7])
    }

    @Test func valueOrSeriesIsRequired() {
        #expect(output(#"{ "chart": { "unit": "%" } }"#, as: nil).failureMessage == #"missing "value" in chart"#)
        #expect(output(#"{ "rows": [] }"#).failureMessage == #"missing "chart""#)
    }

    @Test func aPointThatIsntANumberSaysWhere() {
        #expect(output(#"{ "chart": { "value": 1, "series": [1, "lots"] } }"#).failureMessage == "wrong type at chart.series[1]")
    }

    @Test func unknownTonesReadAsNormal() throws {
        #expect(try chart(#"{ "chart": { "value": 1, "tone": "plaid" } }"#).tone == .normal)
    }

    @Test func numberIsTheValueWhenItIsOne() {
        #expect(ChartContent(value: "64").number == 64)
        #expect(ChartContent(value: " 0.4 ").number == 0.4)
        #expect(ChartContent(value: "4:12").number == nil)
    }
}

struct ChartScaleTests {
    @Test func padsTheSeriesRange() {
        let scale = ChartScale(series: [0, 50, 100])
        #expect(scale.lower == -8)
        #expect(scale.upper == 108)
    }

    @Test func minAndMaxWin() {
        let scale = ChartScale(series: [40, 60], min: 0, max: 100)
        #expect(scale.lower == -8)
        #expect(scale.upper == 108)
    }

    @Test func aThresholdStaysInView() {
        let scale = ChartScale(series: [10, 20], threshold: 40)
        #expect(scale.lower < 10)
        #expect(scale.upper > 40)
    }

    @Test func aFlatSeriesGetsRoom() {
        let scale = ChartScale(series: [5, 5, 5])
        #expect(scale.lower == 4)
        #expect(scale.upper == 6)
        #expect(scale.fraction(5) == 0.5)
    }

    @Test func swappedBoundsStillWork() {
        let scale = ChartScale(series: [], min: 100, max: 0)
        #expect(scale.lower < scale.upper)
    }

    @Test func valuesOutsideAreKeptInside() {
        let scale = ChartScale(lower: 0, upper: 100)
        #expect(scale.fraction(-20) == 0)
        #expect(scale.fraction(150) == 1)
        #expect(scale.fraction(25) == 0.25)
    }

    @Test func pointsSpreadEvenlyOldestLeft() {
        let points = ChartScale(lower: 0, upper: 10).points([0, 5, 10])
        #expect(points == [.init(x: 0, y: 0), .init(x: 0.5, y: 0.5), .init(x: 1, y: 1)])
    }

    @Test func oneValueIsAFlatLine() {
        #expect(ChartScale(lower: 0, upper: 10).points([5]) == [.init(x: 0, y: 0.5), .init(x: 1, y: 0.5)])
        #expect(ChartScale(lower: 0, upper: 10).points([]) == [])
    }
}

struct ChartSummaryTests {
    @Test func minAverageMax() {
        #expect(ChartSummary([18, 34, 50]) == ChartSummary(min: 18, average: 34, max: 50))
        #expect(ChartSummary([]) == nil)
    }

    @Test func formatsInTheValuesPrecision() {
        #expect(ChartContent(value: "64", unit: "%").format(34.25) == "34%")
        #expect(ChartContent(value: "0.4", unit: "%").format(0.125) == "0.1%")
        #expect(ChartContent(value: "21.4", unit: "GB").format(19.06) == "19.1 GB")
        #expect(ChartContent(value: "182", unit: "ms").format(180.4) == "180ms")
        #expect(ChartContent(value: "7").format(-0.2) == "0")
    }

    @Test func aValueThatIsntANumberFormatsByMagnitude() {
        #expect(ChartContent(value: "4:12").format(290.4) == "290")
        #expect(ChartContent(value: "4:12").format(12.34) == "12.3")
        #expect(ChartContent(value: "4:12").format(1.234) == "1.23")
    }
}

struct ChartHistoryTests {
    @Test func appendKeepsTheNewest() {
        #expect(ChartHistory.append(4, to: [1, 2, 3], limit: 3) == [2, 3, 4])
        #expect(ChartHistory.append(1, to: [], limit: 60) == [1])
        #expect(ChartHistory.append(9, to: [1, 2, 3, 4, 5], limit: 2) == [5, 9])
    }

    @Test func fillsTheSeriesOfAChartThatPrintedNone() {
        let (content, kept) = ChartHistory.apply(to: .chart(ChartContent(value: "64")), kept: [31, 28], limit: 60)
        #expect(kept == [31, 28, 64])
        #expect(content == .chart(ChartContent(value: "64", series: [31, 28, 64])))
    }

    @Test func leavesAChartWithItsOwnSeries() {
        let chart = ModuleContent.chart(ChartContent(value: "2", series: [1, 2]))
        let result = ChartHistory.apply(to: chart, kept: [7], limit: 60)
        #expect(result.content == chart)
        #expect(result.kept == [7])
    }

    @Test func leavesEverythingWithoutAHistory() {
        let chart = ModuleContent.chart(ChartContent(value: "2"))
        #expect(ChartHistory.apply(to: chart, kept: [], limit: nil).content == chart)
        let text = ModuleContent.text("2")
        #expect(ChartHistory.apply(to: text, kept: [1], limit: 60).content == text)
        let notANumber = ModuleContent.chart(ChartContent(value: "4:12"))
        let result = ChartHistory.apply(to: notANumber, kept: [1], limit: 60)
        #expect(result.content == notANumber)
        #expect(result.kept == [1])
    }

    @Test func historyIsReadFromPanelJSON() throws {
        let tile = try load([
            "config.json": #"{ "panels": [{ "panel": "x" }] }"#,
            "panels/x/panel.json": #"{ "type": "chart", "command": "./cpu.sh", "history": 60 }"#,
        ]).config.tiles[0]
        #expect(tile.content == .chart)
        #expect(tile.history == 60)
    }

    @Test func historyHasARange() {
        #expect(errors([
            "config.json": #"{ "panels": [{ "panel": "x" }] }"#,
            "panels/x/panel.json": #"{ "type": "chart", "command": "./cpu.sh", "history": 1 }"#,
        ]) == ["panels/x/panel.json: history: 1 is out of range, expected 2 to 1000"])
    }
}
