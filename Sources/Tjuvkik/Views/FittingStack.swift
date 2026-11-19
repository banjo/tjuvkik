import SwiftUI

/// A vertical stack that shows only the children that fit whole: a half-shown row looks broken.
/// A tile scrolls by an item at a time instead, by leaving out the children of the first `skip`
/// list items (see `scrollItem`).
struct FittingStack: Layout {
    var spacing: CGFloat = 0
    /// Keep the last children that fit, aligned to the bottom, instead of the first.
    var fromBottom = false
    /// List items scrolled away at the top.
    var skip = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let height = proposal.height ?? subviews.reduce(0) { $0 + $1.sizeThatFits(.init(width: width, height: nil)).height + spacing }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        if fromBottom {
            placeFromBottom(in: bounds, subviews: subviews)
            return
        }
        var y = bounds.minY
        var full = false
        for subview in subviews {
            if let item = subview[ScrollItemKey.self], item < skip {
                subview.place(at: CGPoint(x: -10_000, y: -10_000), proposal: .zero)
                continue
            }
            let size = subview.sizeThatFits(.init(width: bounds.width, height: nil))
            if full || y + size.height > bounds.maxY + 0.5 {
                full = true
                subview.place(at: CGPoint(x: -10_000, y: -10_000), proposal: .zero)
                continue
            }
            subview.place(at: CGPoint(x: bounds.minX, y: y), proposal: .init(width: bounds.width, height: size.height))
            y += size.height + spacing
        }
    }

    private func placeFromBottom(in bounds: CGRect, subviews: Subviews) {
        var y = bounds.maxY
        var full = false
        for subview in subviews.reversed() {
            let size = subview.sizeThatFits(.init(width: bounds.width, height: nil))
            if full || y - size.height < bounds.minY - 0.5 {
                full = true
                subview.place(at: CGPoint(x: -10_000, y: -10_000), proposal: .zero)
                continue
            }
            y -= size.height
            subview.place(at: CGPoint(x: bounds.minX, y: y), proposal: .init(width: bounds.width, height: size.height))
            y -= spacing
        }
    }
}
