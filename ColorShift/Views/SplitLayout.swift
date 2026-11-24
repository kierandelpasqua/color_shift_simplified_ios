import SwiftUI

/// Stacks the photo over the specimen, giving the photo `photoFraction` of the height (the web's
/// ≤ 900px grid rows, `layoutShares(aspect).mobile`). A custom `Layout` because `containerRelativeFrame`
/// measures the screen, not this container, so it wouldn't follow the drawer (ios.md §8).
/// Animatable, so the split moves smoothly when the photo's aspect changes or the drawer resizes the canvas.
struct SplitLayout: Layout {
    var photoFraction: CGFloat

    var animatableData: CGFloat {
        get { photoFraction }
        set { photoFraction = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        precondition(subviews.count == 2, "SplitLayout takes exactly two views: photo, then specimen")
        let photoHeight = (bounds.height * photoFraction).rounded()
        subviews[0].place(at: bounds.origin, anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: photoHeight))
        subviews[1].place(at: CGPoint(x: bounds.minX, y: bounds.minY + photoHeight), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: bounds.height - photoHeight))
    }
}
