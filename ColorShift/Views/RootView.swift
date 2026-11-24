import SwiftUI

/// The whole screen: the canvas (photo over specimen) with the control deck below it when open.
/// The deck is inserted into the root `VStack`, so opening it pushes the canvas up instead of covering it
/// (PM §11, ios.md I5), animated with the drawer spring.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                canvas
                if model.controlsOpen {
                    ControlDeckView()
                        .frame(height: Self.deckHeight(in: proxy))
                        .frame(maxWidth: .infinity)
                        .background {
                            // One glass surface for the whole deck; nothing inside it is glass (ios.md §5).
                            Rectangle()
                                .fill(Tokens.Surface.canvas.color)
                                .glassEffect(.regular, in: .rect)
                                .ignoresSafeArea(edges: .bottom)
                        }
                        .transition(.move(edge: .bottom))
                }
            }
            .animation(Motion.drawer(reduceMotion: reduceMotion), value: model.controlsOpen)
        }
        .background(Tokens.Surface.canvas.color.ignoresSafeArea())
    }

    /// Web: `min(60dvh, 544px)` of the full screen, measured from the bottom edge. The deck's content sits
    /// above the home indicator and its glass background extends under it, so the inset counts toward it.
    static func deckHeight(in proxy: GeometryProxy) -> CGFloat {
        let insets = proxy.safeAreaInsets
        let screen = proxy.size.height + insets.top + insets.bottom
        return min(Tokens.Size.deckHeightFraction * screen, Tokens.Size.deckMaxHeight) - insets.bottom
    }

    private var canvas: some View {
        SplitLayout(photoFraction: CGFloat(ColorMath.layoutShares(aspect: model.photo.aspect).mobile) / 100) {
            PhotoPanelView()
            SpecimenView()
        }
        // The photo bleeds under the status bar; with the deck closed, the specimen fills to the bottom edge.
        .ignoresSafeArea(edges: model.controlsOpen ? .top : [.top, .bottom])
        .overlay(alignment: .bottomLeading) {
            MixerToggle()
                .padding(Tokens.Spacing.m)
        }
    }
}

#Preview {
    RootView().environment(AppModel())
}
