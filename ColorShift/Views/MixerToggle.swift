import SwiftUI

/// The 48pt button that opens and closes the control deck (PM §9). Regular, untinted Liquid Glass
/// (ios.md §5); pinned to the canvas's bottom-leading corner, so it rides up with the canvas.
struct MixerToggle: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GlassEffectContainer {
            Button {
                model.controlsOpen.toggle()
            } label: {
                MixerIcon()
                    .stroke(style: StrokeStyle(lineWidth: Tokens.Size.mixerIconStroke, lineCap: .round, lineJoin: .round))
                    .frame(width: Tokens.Size.mixerIcon, height: Tokens.Size.mixerIcon)
                    .foregroundStyle(Tokens.Text.primary.color)
                    .frame(width: Tokens.Size.mixerToggle, height: Tokens.Size.mixerToggle)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
        }
        .accessibilityLabel(model.controlsOpen ? "Close color controls" : "Open color controls")
        .accessibilityIdentifier("mixerToggle")
    }
}
