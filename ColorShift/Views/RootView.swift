import SwiftUI

/// The whole screen: the canvas (photo over specimen) with the control deck below it when open.
/// The deck is inserted into the root `VStack`, so opening it pushes the canvas up instead of covering it
/// (PM §11, ios.md I5). The deck and mixer toggle arrive in T-023; the photo panel in T-022.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            SplitLayout(photoFraction: CGFloat(ColorMath.layoutShares(aspect: model.photo.aspect).mobile) / 100) {
                // Placeholder until the photo panel (T-022).
                Tokens.Surface.photoPlaceholder.color
                SpecimenView()
            }
            // The photo bleeds under the status bar; with the deck closed, the specimen fills to the bottom edge.
            .ignoresSafeArea(edges: [.top, .bottom])
        }
        .background(Tokens.Surface.canvas.color)
    }
}

#Preview {
    RootView().environment(AppModel())
}
