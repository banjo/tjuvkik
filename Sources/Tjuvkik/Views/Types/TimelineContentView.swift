import AppKit
import SwiftUI
import TjuvkikCore

/// What's now, what's next and how long until. s counts down, m draws the window as a strip with
/// now and next below, l an agenda with hour lines. Draws now itself, every 30 seconds, so the
/// tile stays right between runs. Named apart from SwiftUI's `TimelineView`, which it uses.
struct TimelineContentView: View {
    let content: TimelineContent
    let size: TileSize
    let theme: Theme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let snapshot = content.snapshot(now: context.date, calendar: .autoupdatingCurrent)
            switch TileLayout(size) {
            case .s: TimelineCountdown(countdown: snapshot.countdown, theme: theme)
            case .m: TimelineStrip(snapshot: snapshot, theme: theme)
            case .l: TimelineAgenda(snapshot: snapshot, theme: theme)
            }
        }
    }
}

// MARK: s

/// The current event's time left, or the next one's time until, big at the bottom.
private struct TimelineCountdown: View {
    let countdown: TimelineContent.Snapshot.Countdown
    let theme: Theme

    var body: some View {
        let tone = theme.color(for: countdown.tone ?? .accent, default: theme.text)
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            if let label = countdown.label {
                Text(label).font(theme.font(11.5)).foregroundStyle(Color(theme.secondaryText)).lineLimit(1)
            }
            if let value = countdown.value {
                Text(value)
                    .font(theme.font(30, weight: .semibold).monospacedDigit())
                    .tracking(-0.6)
                    .foregroundStyle(tone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(countdown.title)
                .font(theme.font(13, weight: .medium))
                .foregroundStyle(Color(countdown.value == nil ? theme.tertiaryText : theme.text))
                .lineLimit(1)
                .padding(.top, countdown.value == nil ? 0 : 8)
            if let detail = countdown.detail {
                Text(detail)
                    .font(theme.font(11.5))
                    .foregroundStyle(Color(theme.secondaryText))
                    .lineLimit(1)
                    .padding(.top, 2)
            }
            if let progress = countdown.progress {
                GeometryReader { geometry in
                    Capsule().fill(Color(theme.well))
                        .overlay(alignment: .leading) {
                            Capsule().fill(tone).frame(width: geometry.size.width * progress)
                        }
                }
                .frame(height: 4)
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
}

// MARK: m

/// The window as a strip, its axis, and now, next and what's left below.
private struct TimelineStrip: View {
    let snapshot: TimelineContent.Snapshot
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geometry in
                strip(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(height: 34)
            .padding(.top, 4)
            GeometryReader { geometry in
                TimelineAxis(ticks: snapshot.ticks(max: max(Int(geometry.size.width / 60), 2)), width: geometry.size.width, theme: theme)
            }
            .frame(height: 14)
            .padding(.top, 5)
            Spacer(minLength: 6)
            notes
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func strip(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(theme.well))
            ForEach(snapshot.items.filter(\.isInWindow), id: \.index) { item in
                let x = width * item.from
                let boxWidth = max(width * (item.to - item.from) - 2, 6)
                TimelineEventBox(tone: theme.color(for: item.event.tone ?? .accent, default: theme.text),
                                 fill: theme.eventFill(item), state: item.state, radius: 5) {
                    // Too narrow for a readable title: color only; the notes below name what matters.
                    ViewThatFits(in: .horizontal) {
                        Text(item.event.title)
                            .font(theme.font(10.5, weight: .semibold))
                            .foregroundStyle(Color(theme.text))
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 6)
                        Color.clear
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                .frame(width: boxWidth, height: max(height - 8, 0))
                .clickable(RowAction(url: item.event.url, command: item.event.command), theme: theme, radius: 5, tone: item.event.tone)
                .offset(x: x, y: 4)
            }
            if let now = snapshot.nowPosition {
                NowMarker(vertical: true, length: height + 8, theme: theme)
                    .offset(x: width * now - 3.5, y: -7)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    @ViewBuilder private var notes: some View {
        let notes = snapshot.notes
        if notes.isEmpty {
            Text("Nothing coming up").font(theme.font(12)).foregroundStyle(Color(theme.tertiaryText)).lineLimit(1)
        } else {
            // Drop notes from the right until the rest fit.
            ViewThatFits(in: .horizontal) {
                noteRow(notes)
                noteRow(Array(notes.prefix(2)))
                noteRow(Array(notes.prefix(1)))
            }
        }
    }

    private func noteRow(_ notes: [TimelineContent.Snapshot.Note]) -> some View {
        HStack(alignment: .top, spacing: 18) {
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.key.uppercased())
                        .font(theme.font(10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Color(theme.tertiaryText))
                    noteLine(note)
                        .font(theme.font(12))
                        .lineLimit(1)
                }
            }
        }
    }

    private func noteLine(_ note: TimelineContent.Snapshot.Note) -> Text {
        let title = Text(note.title).fontWeight(.medium).foregroundStyle(Color(theme.text))
        guard let detail = note.detail else { return title }
        return Text("\(title) \(Text(detail).foregroundStyle(Color(theme.secondaryText)))")
    }
}

/// Tick labels under the strip: centered on their place, moved in where they'd stick out at the ends.
private struct TimelineAxis: View {
    let ticks: [TimelineContent.Snapshot.Tick]
    let width: CGFloat
    let theme: Theme

    var body: some View {
        let font = theme.nsFont(10).monospacedDigits
        ZStack(alignment: .topLeading) {
            ForEach(Array(ticks.enumerated()), id: \.offset) { _, tick in
                let label = ceil((tick.label as NSString).size(withAttributes: [.font: font]).width)
                Text(tick.label)
                    .font(theme.font(10).monospacedDigit())
                    .foregroundStyle(Color(theme.tertiaryText))
                    .fixedSize()
                    .offset(x: min(max(width * tick.position - label / 2, 0), max(width - label, 0)))
            }
        }
        .frame(width: width, alignment: .topLeading)
    }
}

// MARK: l

/// Hour lines down the left, events placed by time, side by side where they overlap, and a now line.
private struct TimelineAgenda: View {
    let snapshot: TimelineContent.Snapshot
    let theme: Theme

    /// Room for the hour labels, left of the events.
    private let gutter: CGFloat = 34

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - gutter
            let height = geometry.size.height
            ZStack(alignment: .topLeading) {
                ForEach(Array(snapshot.ticks(max: max(Int(height / 22), 2)).enumerated()), id: \.offset) { _, tick in
                    if tick.position < 0.999 {
                        Rectangle().fill(Color(theme.line))
                            .frame(width: width, height: 1)
                            .offset(x: gutter, y: height * tick.position)
                        Text(tick.label)
                            .font(theme.font(10).monospacedDigit())
                            .foregroundStyle(Color(theme.tertiaryText))
                            .fixedSize()
                            .offset(y: height * tick.position - 6)
                    }
                }
                ForEach(snapshot.items.filter(\.isInWindow), id: \.index) { item in
                    let laneWidth = width / CGFloat(max(item.lanes, 1))
                    let top = height * item.from + 1
                    let boxHeight = max(height * (item.to - item.from) - 2, 20)
                    event(item, short: boxHeight < 34)
                        .frame(width: max(laneWidth - (item.lanes > 1 ? 2 : 0), 0), height: boxHeight)
                        .clickable(RowAction(url: item.event.url, command: item.event.command), theme: theme, tone: item.event.tone)
                        .offset(x: gutter + laneWidth * CGFloat(item.lane), y: top)
                }
                if let now = snapshot.nowPosition {
                    NowMarker(vertical: false, length: width + 6, theme: theme)
                        .offset(x: gutter - 6 - 3, y: height * now - 3.5)
                }
                if snapshot.items.isEmpty {
                    Text("Nothing scheduled")
                        .font(theme.font(11.5))
                        .foregroundStyle(Color(theme.tertiaryText))
                        .frame(width: width, height: height)
                        .offset(x: gutter)
                }
            }
            .frame(width: geometry.size.width, height: height, alignment: .topLeading)
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private func event(_ item: TimelineContent.Snapshot.Item, short: Bool) -> some View {
        TimelineEventBox(tone: theme.color(for: item.event.tone ?? .accent, default: theme.text), fill: theme.eventFill(item), state: item.state, radius: 6) {
            Group {
                if short {
                    Text("\(Text(item.event.title).fontWeight(.semibold)) \(Text(item.startTime).font(theme.font(10.5)).foregroundStyle(Color(theme.secondaryText)))")
                        .font(theme.font(11.5))
                        .foregroundStyle(Color(theme.text))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.event.title)
                            .font(theme.font(11.5, weight: .semibold))
                            .foregroundStyle(Color(theme.text))
                            .lineLimit(1)
                        Text(item.detail)
                            .font(theme.font(10.5))
                            .foregroundStyle(Color(theme.secondaryText))
                            .lineLimit(1)
                    }
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

// MARK: Parts

/// An event's block: `fill`, with a bar of its tone on the left. Past events fade; the current
/// one gets an outline.
private struct TimelineEventBox<Label: View>: View {
    let tone: Color
    let fill: Color
    let state: TimelineContent.Snapshot.State
    let radius: CGFloat
    @ViewBuilder let label: Label

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack(alignment: .leading) {
            shape.fill(fill)
            Rectangle().fill(tone).frame(width: 2)
            label
        }
        .clipShape(shape)
        .overlay {
            if state == .now { shape.strokeBorder(tone.opacity(0.45), lineWidth: 1) }
        }
        .opacity(state == .past ? 0.45 : 1)
    }
}

/// The now line with a dot at its start: across the agenda, or down through the strip.
private struct NowMarker: View {
    let vertical: Bool
    /// The line's length, past the dot.
    let length: CGFloat
    let theme: Theme

    var body: some View {
        let color = Color(theme.error)
        if vertical {
            ZStack(alignment: .top) {
                Rectangle().fill(color).frame(width: 1.5, height: length).offset(y: 3)
                Circle().fill(color).frame(width: 7, height: 7)
            }
            .frame(width: 7, alignment: .top)
        } else {
            ZStack(alignment: .leading) {
                Rectangle().fill(color).frame(width: length, height: 1.5).offset(x: 3)
                Circle().fill(color).frame(width: 7, height: 7)
            }
            .frame(height: 7, alignment: .leading)
        }
    }
}

extension Theme {
    fileprivate func eventFill(_ item: TimelineContent.Snapshot.Item) -> Color {
        let tone = item.event.tone ?? .accent
        return background(for: tone, color: color(for: tone, default: text), opacity: 0.16)
    }
}
