import AppKit
import SwiftUI

/// Placeholder board until modules exist: an agents tile and four small tiles.
struct GlanceView: View {
    let model: GlanceModel

    var body: some View {
        HStack(spacing: 10) {
            PlaceholderTile(title: "Agents", index: 0, isVisible: model.isVisible)
                .frame(maxWidth: .infinity)
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    PlaceholderTile(title: "GitHub", index: 1, isVisible: model.isVisible)
                    PlaceholderTile(title: "Jira", index: 2, isVisible: model.isVisible)
                }
                GridRow {
                    PlaceholderTile(title: "Calendar", index: 3, isVisible: model.isVisible)
                    PlaceholderTile(title: "Builds", index: 4, isVisible: model.isVisible)
                }
                GridRow {
                    PlaceholderTile(title: "Pods", index: 5, isVisible: model.isVisible)
                        .gridCellColumns(2)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PlaceholderTile: View {
    let title: String
    let index: Int
    let isVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(VisualEffect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.08)))
        .environment(\.colorScheme, .dark)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible || reduceMotion ? 1 : 0.97)
        .animation(.easeOut(duration: 0.22).delay(Double(index) * 0.03), value: isVisible)
    }
}
