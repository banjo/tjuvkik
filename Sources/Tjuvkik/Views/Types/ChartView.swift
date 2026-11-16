import SwiftUI
import TjuvkikCore

/// One number and where it's heading. s shows the value and change over a sparkline, m the value
/// left of the chart, l the chart with a threshold line, axis labels and min/avg/max.
struct ChartView: View {
    let content: ChartContent
    let size: TileSize
    let theme: Theme

    var body: some View {
        switch TileLayout(size) {
        case .s: small
        case .m: medium
        case .l: large
        }
    }

    private var lineColor: Color {
        theme.color(for: content.tone ?? .accent, default: theme.accent)
    }

    private var delta: some View {
        DeltaLine(delta: content.delta?.text, tone: content.delta?.tone, vs: nil, theme: theme)
    }

    private func value(size: CGFloat) -> some View {
        ValueText(value: content.value, unit: content.unit, size: size, unitSize: 15, theme: theme)
            .minimumScaleFactor(0.6)
    }

    private func label(lines: Int) -> some View {
        Text(content.label ?? "")
            .font(.system(size: 11.5))
            .foregroundStyle(Color(theme.secondaryText))
            .lineLimit(lines)
    }

    private func plot(threshold: Bool, grid: Bool) -> some View {
        let scale = ChartScale(series: content.series, min: content.min, max: content.max, threshold: threshold ? content.threshold : nil)
        return ChartPlot(
            points: scale.points(content.series),
            threshold: threshold ? content.threshold.map { (fraction: scale.fraction($0), text: content.format($0)) } : nil,
            grid: grid,
            color: lineColor,
            theme: theme
        )
        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }

    // MARK: Sizes

    /// The value and change, the sparkline below them filling the rest.
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            value(size: 26)
            if content.delta != nil { delta.padding(.top, 4) }
            plot(threshold: false, grid: false).padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The value, label and change at the bottom left, the chart to the right.
    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Spacer(minLength: 0)
                value(size: 30)
                if content.label != nil { label(lines: 2) }
                if content.delta != nil { delta }
            }
            .padding(.bottom, 2)
            .frame(width: 150, alignment: .bottomLeading)
            .frame(maxHeight: .infinity, alignment: .bottomLeading)
            plot(threshold: false, grid: false).padding(.top, 2)
        }
    }

    /// The value and change on top, then the label, the chart with its grid and threshold, the
    /// axis labels and min/avg/max.
    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                value(size: 30).layoutPriority(1)
                if content.delta != nil { delta }
            }
            if content.label != nil { label(lines: 1).padding(.top, 3) }
            plot(threshold: true, grid: true).padding(.top, 10)
            if !content.axis.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(content.axis.enumerated()), id: \.offset) { index, text in
                        if index > 0 { Spacer(minLength: 4) }
                        Text(text)
                    }
                }
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(Color(theme.tertiaryText))
                .lineLimit(1)
                .padding(.top, 6)
            }
            if let summary = content.summary {
                HStack(spacing: 12) {
                    footerItem("min", summary.min)
                    footerItem("avg", summary.average)
                    footerItem("max", summary.max)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func footerItem(_ name: String, _ number: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(name).foregroundStyle(Color(theme.tertiaryText))
            Text(content.format(number)).fontWeight(.medium).foregroundStyle(Color(theme.secondaryText))
        }
        .font(.system(size: 11).monospacedDigit())
        .lineLimit(1)
        .fixedSize()
    }
}

/// The line, the fill under it and a dot on the newest value. Optionally a faint grid and a
/// dashed threshold line with its value.
private struct ChartPlot: View {
    let points: [ChartPoint]
    /// Where the threshold sits, 0 to 1 from the bottom, and its label.
    let threshold: (fraction: Double, text: String)?
    let grid: Bool
    let color: Color
    let theme: Theme

    /// Room on the right for the dot on the last value.
    private static let dot: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(x: 0, y: 0, width: max(proxy.size.width - Self.dot / 2, 0), height: proxy.size.height)
            ZStack(alignment: .topLeading) {
                if grid {
                    Path { path in
                        for fraction: Double in [0.25, 0.5, 0.75] {
                            let y = rect.height * CGFloat(fraction)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                        }
                    }
                    .stroke(Color(theme.line), lineWidth: 1)
                }
                if let threshold {
                    let y = rect.height * CGFloat(1 - threshold.fraction)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }
                    .stroke(Color(theme.warning).opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    Text(threshold.text)
                        .font(.system(size: 9.5).monospacedDigit())
                        .foregroundStyle(Color(theme.warning).opacity(0.8))
                        .lineLimit(1)
                        .fixedSize()
                        .frame(width: proxy.size.width, alignment: .trailing)
                        // Above the line, or below it when it's at the top.
                        .offset(y: y >= 14 ? y - 14 : y + 2)
                }
                if !points.isEmpty {
                    Self.area(points, in: rect)
                        .fill(LinearGradient(colors: [color.opacity(0.32), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    Self.line(points, in: rect)
                        .stroke(color, style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round))
                    if let last = points.last {
                        Circle()
                            .fill(color)
                            .frame(width: Self.dot, height: Self.dot)
                            .position(Self.point(last, in: rect))
                    }
                }
            }
        }
    }

    private static func point(_ point: ChartPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + CGFloat(point.x) * rect.width, y: rect.minY + CGFloat(1 - point.y) * rect.height)
    }

    private static func line(_ points: [ChartPoint], in rect: CGRect) -> Path {
        Path { path in
            for (index, chartPoint) in points.enumerated() {
                let at = point(chartPoint, in: rect)
                if index == 0 { path.move(to: at) } else { path.addLine(to: at) }
            }
        }
    }

    private static func area(_ points: [ChartPoint], in rect: CGRect) -> Path {
        var path = line(points, in: rect)
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: point(last, in: rect).x, y: rect.maxY))
        path.addLine(to: CGPoint(x: point(first, in: rect).x, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
