import SwiftUI

/// Foreground and background fields (swatch + hex; tap opens the system color picker) with the swap
/// button between them (PM §9). Web ≤ 560px: max width 320.
struct ColorReadout: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        @Bindable var model = model
        AdaptiveStack(spacing: 8.8) {
            ColorField(title: "Foreground", color: $model.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                model.swap()
            } label: {
                ScaledIcon(icon: SwapIcon())
                    .foregroundStyle(Tokens.Icon.swap.color)
                    .frame(width: Tokens.Size.swapButton, height: Tokens.Size.swapButton)
                    .overlay(Circle().strokeBorder(Tokens.Line.swap.color, lineWidth: 1))
                    .frame(width: Tokens.Size.minHitTarget, height: Tokens.Size.minHitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Swap foreground and background")
            .accessibilityIdentifier("swapButton")
            ColorField(title: "Background", color: $model.background)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 320, alignment: .leading)
    }
}

private struct ColorField: View {
    let title: String
    @Binding var color: SRGB8
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button {
            ColorPickerPresenter.shared.present(title: title, color: color) { color = $0 }
        } label: {
            VStack(alignment: .leading, spacing: 7.68) {
                Text(title)
                    .typeStyle(Typography.fieldLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(Tokens.Text.muted(contrast).color)
                HStack(spacing: 7.68) {
                    Circle()
                        .fill(color.color)
                        .overlay(Circle().strokeBorder(Tokens.Line.swatchBorder.color, lineWidth: 1))
                        .frame(width: Tokens.Size.swatch, height: Tokens.Size.swatch)
                        .accessibilityIgnoresInvertColors()
                    Text(verbatim: color.hex)
                        .typeStyle(Typography.hexValue)
                        .monospacedDigit()
                        .foregroundStyle(Tokens.Text.deck.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(minHeight: Tokens.Size.minHitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) color")
        .accessibilityValue(color.hex)
        .accessibilityHint("Opens the color picker")
        .accessibilityIdentifier("colorField.\(title)")
    }
}
