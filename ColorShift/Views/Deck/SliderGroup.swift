import SwiftUI

/// "FG MIX" / "BG MIX": heading with `H° · S% · L%`, then Hue, Sat and Light rows (PM §9).
/// Integer steps; a color is rewritten only when a slider actually moves (ios.md §14).
struct SliderGroup: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let role: ColorRole

    private var color: SRGB8 { role == .foreground ? model.foreground : model.background }
    private var roleName: String { role == .foreground ? "Foreground" : "Background" }

    var body: some View {
        let hsl = color.hsl
        // Rows are 44pt touch targets, which already space them (the web's 10.24pt gap is between 12pt rows).
        VStack(alignment: .leading, spacing: 0) {
            AdaptiveStack(spacing: 4) {
                Text(role == .foreground ? "FG mix" : "BG mix")
                    .typeStyle(Typography.sectionTitle)
                    .foregroundStyle(Tokens.Text.deck.color)
                    .accessibilityAddTraits(.isHeader)
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Text(verbatim: "\(hsl.h)° · \(hsl.s)% · \(hsl.l)%")
                    .typeStyle(Typography.fieldLabel)
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Text.muted(contrast).color)
                    .accessibilityLabel("Hue \(hsl.h) degrees, saturation \(hsl.s) percent, lightness \(hsl.l) percent")
            }
            .padding(.bottom, 4)
            HSLSlider(label: "Hue", accessibilityName: "\(roleName) hue", unit: "degrees", value: hsl.h, maximum: 360,
                      track: .hue) { model.setChannel(role, .hue, $0) }
            HSLSlider(label: "Sat", accessibilityName: "\(roleName) saturation", unit: "percent", value: hsl.s, maximum: 100,
                      track: .toward(color)) { model.setChannel(role, .saturation, $0) }
            HSLSlider(label: "Light", accessibilityName: "\(roleName) lightness", unit: "percent", value: hsl.l, maximum: 100,
                      track: .toward(color)) { model.setChannel(role, .lightness, $0) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(role == .foreground ? "deck.fgMix" : "deck.bgMix")
    }
}

private struct HSLSlider: View {
    enum Track { case hue, toward(SRGB8) }

    let label: String
    let accessibilityName: String
    let unit: String
    let value: Int
    let maximum: Int
    let track: Track
    let onChange: (Int) -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility sizes the label sits above the track instead of in a 35pt column.
        AdaptiveStack(spacing: dynamicTypeSize.isAccessibilitySize ? 0 : 7.2) {
            Text(label)
                .typeStyle(Typography.fieldLabel)
                .foregroundStyle(Tokens.Text.muted(contrast).color)
                .lineLimit(1)
                .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 35.2, alignment: .leading)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.7)
            GeometryReader { proxy in
                let width = proxy.size.width
                let x = SliderMath.x(for: value, maximum: maximum, width: width)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: trackColors, startPoint: .leading, endPoint: .trailing))
                        .frame(height: Tokens.Size.sliderTrack)
                        .accessibilityIgnoresInvertColors()   // the track shows real colors
                    Circle()
                        .fill(Tokens.Thumb.fill.color)
                        .overlay(Circle().strokeBorder(Tokens.Surface.canvas.color, lineWidth: 2))
                        .overlay(Circle().stroke(Tokens.Thumb.ring.color, lineWidth: 1))
                        .frame(width: Tokens.Size.sliderThumb, height: Tokens.Size.sliderThumb)
                        .offset(x: x - Tokens.Size.sliderThumb / 2)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                // Horizontal pans drag the thumb; vertical swipes fall through to the deck's scroll view.
                .gesture(HorizontalPanGesture { x in set(x: x, width: width) })
                .gesture(TapLocationGesture { x in set(x: x, width: width) })
            }
            .frame(height: Tokens.Size.minHitTarget)
        }
        // One adjustable element per row (VoiceOver swipe up/down = ±1).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue("\(value) \(unit)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if value < maximum { onChange(value + 1) }
            case .decrement: if value > 0 { onChange(value - 1) }
            @unknown default: break
            }
        }
        .accessibilityIdentifier("slider.\(accessibilityName)")
    }

    private func set(x: CGFloat, width: CGFloat) {
        let next = SliderMath.value(at: x, maximum: maximum, width: width)
        if next != value { onChange(next) }
    }

    private var trackColors: [Color] {
        switch track {
        case .hue: Tokens.hueGradient.map(\.color)
        case .toward(let color): [Tokens.Surface.sliderStart.color, color.color]
        }
    }
}

/// Maps between slider values and track positions. The thumb's center travels the full track width.
nonisolated enum SliderMath {
    static func value(at x: CGFloat, maximum: Int, width: CGFloat) -> Int {
        guard width > 0 else { return 0 }
        let fraction = min(1, max(0, x / width))
        return Int(SRGB8.jsRound(fraction * Double(maximum)))
    }

    static func x(for value: Int, maximum: Int, width: CGFloat) -> CGFloat {
        guard maximum > 0 else { return 0 }
        return width * CGFloat(min(maximum, max(0, value))) / CGFloat(maximum)
    }
}
