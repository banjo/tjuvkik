import SwiftUI
import TjuvkikCore

/// How full, how far, how close to a limit. s shows the first meter as a ring with its value
/// inside, m up to three big values with bars, l a list of bars with limit marks and the footer.
struct MetersView: View {
    let content: MetersContent
    let size: TileSize
    let theme: Theme

    var body: some View {
        switch TileLayout(size) {
        case .s:
            if let meter = content.meters.first { MeterRing(meter: meter, theme: theme) }
        case .m:
            let meters = Array(content.meters.prefix(3))
            HStack(alignment: .bottom, spacing: theme.z(14)) {
                ForEach(Array(meters.enumerated()), id: \.offset) { _, meter in column(meter) }
                // Three columns always, so fewer meters keep the widths of a full row.
                ForEach(meters.count..<3, id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: theme.z(1)) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .l:
            VStack(alignment: .leading, spacing: 0) {
                MeterStack(minSpacing: theme.z(11)) {
                    ForEach(Array(content.meters.enumerated()), id: \.offset) { _, meter in row(meter) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if let footer = content.footer, !footer.isEmpty {
                    Text(footer)
                        .font(theme.font(11).monospacedDigit())
                        .foregroundStyle(Color(theme.tertiaryText))
                        .lineLimit(1)
                        .padding(.top, theme.z(8))
                }
            }
        }
    }

    private func tone(_ meter: MetersContent.Meter) -> Color {
        theme.color(for: meter.tone, default: theme.accent)
    }

    /// m: label, big value with what it's out of, bar.
    private func column(_ meter: MetersContent.Meter) -> some View {
        VStack(alignment: .leading, spacing: theme.z(5)) {
            Text(meter.label ?? " ")
                .font(theme.font(11.5))
                .foregroundStyle(Color(theme.secondaryText))
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(meter.text)
                    .font(theme.font(22, weight: .semibold).monospacedDigit())
                    .tracking(theme.z(-0.44))
                    .foregroundStyle(tone(meter))
                    .layoutPriority(1)
                if let of = meter.of {
                    Text(" / \(of)")
                        .font(theme.font(12, weight: .medium).monospacedDigit())
                        .foregroundStyle(Color(theme.secondaryText))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            MeterBar(meter: meter, color: tone(meter), theme: theme)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// l: label left, value and what it's out of right, bar below.
    private func row(_ meter: MetersContent.Meter) -> some View {
        VStack(spacing: theme.z(5)) {
            HStack(alignment: .firstTextBaseline, spacing: theme.z(8)) {
                Text(meter.label ?? "")
                    .font(theme.font(12.5))
                    .foregroundStyle(Color(theme.text))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(meter.text)
                        .fontWeight(.semibold)
                        .foregroundStyle(tone(meter))
                    if let of = meter.of {
                        Text(" / \(of)").foregroundStyle(Color(theme.secondaryText))
                    }
                }
                .font(theme.font(11.5).monospacedDigit())
                .lineLimit(1)
                .fixedSize()
            }
            MeterBar(meter: meter, color: tone(meter), theme: theme)
        }
    }
}

/// A 6 pt bar on the well, filled to the meter's fraction, with a tick at its mark.
private struct MeterBar: View {
    let meter: MetersContent.Meter
    let color: Color
    let theme: Theme

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color(theme.well))
                Capsule().fill(color).frame(width: width * meter.fraction)
            }
            // An overlay, so the tick reaches 2 pt past the bar without making it taller.
            .overlay(alignment: .leading) {
                if let mark = meter.markFraction {
                    Rectangle()
                        .fill(ink.opacity(0.45))
                        .frame(width: theme.z(1.5), height: theme.z(10))
                        .offset(x: max(0, min(width * mark - theme.z(0.75), width - theme.z(1.5))))
                }
            }
        }
        .frame(height: theme.z(6))
    }

    /// White on dark themes, black on light, like the prototype's `--ink`.
    private var ink: Color { theme.appearance == .dark ? .white : .black }
}

/// s: the first meter as a ring, its value and label inside.
private struct MeterRing: View {
    let meter: MetersContent.Meter
    let theme: Theme

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height, theme.z(112))
            let line = side * 0.09
            let color = theme.color(for: meter.tone, default: theme.accent)
            ZStack {
                Circle()
                    .stroke(Color(theme.well), lineWidth: line)
                Circle()
                    .trim(from: 0, to: meter.fraction)
                    .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: theme.z(2)) {
                    Text(meter.text)
                        .font(theme.font(22, weight: .semibold).monospacedDigit())
                        .tracking(theme.z(-0.44))
                        .foregroundStyle(color)
                    if let caption {
                        Text(caption)
                            .font(theme.font(10.5))
                            .foregroundStyle(Color(theme.secondaryText))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: side * 0.72)
            }
            // The stroke is centered on the circle's edge; inset so it isn't cut.
            .padding(line / 2)
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The label, else what the value is out of.
    private var caption: String? {
        if let label = meter.label, !label.isEmpty { return label }
        return meter.of.map { "of \($0)" }
    }
}

/// A vertical stack that shows only the children that fit whole, at least `minSpacing` apart,
/// with the room left spread evenly around them, like CSS's `space-evenly`.
private struct MeterStack: Layout {
    var minSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let height = proposal.height ?? subviews.reduce(0) { $0 + $1.sizeThatFits(.init(width: width, height: nil)).height + minSpacing }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let heights = subviews.map { $0.sizeThatFits(.init(width: bounds.width, height: nil)).height }
        var count = 0
        var used: CGFloat = 0
        for height in heights {
            let next = used + height + (count == 0 ? 0 : minSpacing)
            if next > bounds.height + 0.5 { break }
            used = next
            count += 1
        }
        let content = heights.prefix(count).reduce(0, +)
        let free = max(bounds.height - content, 0)
        // Even gaps around and between, unless that squeezes the ones between below the minimum.
        var edge = free / CGFloat(count + 1)
        var between = edge
        if count > 1 && edge < minSpacing {
            edge = 0
            between = free / CGFloat(count - 1)
        }
        var y = bounds.minY + edge
        for (index, subview) in subviews.enumerated() {
            guard index < count else {
                subview.place(at: CGPoint(x: -10_000, y: -10_000), proposal: .zero)
                continue
            }
            subview.place(at: CGPoint(x: bounds.minX, y: y), proposal: .init(width: bounds.width, height: heights[index]))
            y += heights[index] + between
        }
    }
}
