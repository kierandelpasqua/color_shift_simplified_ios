import SwiftUI

/// WCAG/APCA switch and score, the WCAG meter with AA/AAA tick buttons, and the Jump button (PM §9).
/// The meter and jumps are always WCAG, even in APCA mode (PM §8.11).
struct ContrastBlock: View {
    @Environment(AppModel.self) private var model
    /// A jump that couldn't reach its target, shown until the colors change (ios.md §14).
    @State private var miss: (target: Double, pair: ColorPair)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var pair: ColorPair { ColorPair(background: model.background, foreground: model.foreground) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AdaptiveStack(spacing: Tokens.Spacing.xs) {
                ModeSwitch()
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: Tokens.Spacing.s) }
                score
            }
            .padding(.bottom, 19.2 - 11)   // web margin, less the switch's taller hit area

            ContrastMeter(ratio: model.wcag, onJump: jump)

            if dynamicTypeSize.isAccessibilitySize {
                // Tick labels collide at these sizes, so they move to a legend row under the meter.
                HStack(spacing: Tokens.Spacing.m) {
                    TickLegend(name: "AA", value: "4.5", passes: model.wcag >= ColorMath.aa)
                    TickLegend(name: "AAA", value: "7", passes: model.wcag >= ColorMath.aaa)
                }
                .padding(.bottom, Tokens.Spacing.s)
            }

            AdaptiveStack(horizontalAlignment: .leading, verticalAlignment: .firstTextBaseline, spacing: Tokens.Spacing.s) {
                if let miss, miss.pair == pair {
                    Text(miss.target == ColorMath.aaa ? "Can't reach AAA with this hue" : "Can't reach AA with this hue")
                        .typeStyle(Typography.button)
                        .foregroundStyle(Tokens.Text.deck.color)
                        .accessibilityIdentifier("jumpMissMessage")
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                jumpButton
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("deck.contrast")
    }

    private var score: some View {
        Group {
            switch model.mode {
            case .wcag:
                Text(verbatim: "\(ColorMath.formatRatio(model.wcag)):1")
                    .contentTransition(.numericText(value: model.wcag))
            case .apca:
                Text(verbatim: "\(APCA.displayValue(model.apca)) Lc")
                    .contentTransition(.numericText(value: Double(APCA.displayValue(model.apca))))
            }
        }
        .typeStyle(Typography.contrastValue)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .foregroundStyle(Tokens.Text.deck.color)
        .animation(Motion.colorChange, value: model.wcag)
        .accessibilityLabel("Contrast")
        .accessibilityValue(model.mode == .wcag
            ? "\(ColorMath.formatRatio(model.wcag)) to 1"
            : "\(APCA.displayValue(model.apca)) L c")
        .accessibilityIdentifier("contrastScore")
    }

    private var jumpButton: some View {
        let target = ColorMath.Meter.nextTarget(for: model.wcag)
        let name = target == ColorMath.aa ? "AA" : "AAA"
        return Button {
            jump(to: target)
        } label: {
            HStack(spacing: 6.4) {
                Text(verbatim: "Jump to \(name)")
                    .typeStyle(Typography.button)
                ScaledIcon(icon: ArrowIcon())
            }
            .foregroundStyle(Tokens.Text.button.color)
            .padding(.vertical, 8)
            .padding(.horizontal, 9.92)
            .background(Tokens.Surface.button.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.button))
            .frame(minHeight: Tokens.Size.minHitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Jump to WCAG \(name) contrast")
        .accessibilityIdentifier("jumpButton")
    }

    private func jump(to target: Double) {
        let reached = model.jump(to: target)
        miss = reached ? nil : (target, pair)
        AccessibilityNotification.Announcement(Self.announcement(ratio: model.wcag, target: target, reached: reached)).post()
    }

    /// e.g. "Contrast now 4.62 to 1, passes AA" (ios.md §11).
    static func announcement(ratio: Double, target: Double, reached: Bool) -> String {
        let name = target == ColorMath.aaa ? "AAA" : "AA"
        let level = ratio >= ColorMath.aaa ? "passes AAA" : ratio >= ColorMath.aa ? "passes AA" : "fails AA"
        let now = "Contrast now \(ColorMath.formatRatio(ratio)) to 1, \(level)"
        return reached ? now : "Can't reach \(name) with this hue. \(now)"
    }
}

/// WCAG / APCA capsule switch (web `.mode-switch`).
private struct ModeSwitch: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ContrastMode.allCases, id: \.self) { mode in
                let isSelected = model.mode == mode
                Button {
                    model.mode = mode
                } label: {
                    Text(mode.rawValue)
                        .typeStyle(Typography.segment)
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle((isSelected ? Tokens.Surface.canvas : Tokens.Text.chip).color)
                        .padding(.vertical, 6.08)
                        .padding(.horizontal, 7.68)
                        .background(Capsule().fill(isSelected ? Tokens.Selected.segment.color : .clear))
                        .frame(minHeight: Tokens.Size.minHitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("mode.\(mode.rawValue)")
            }
        }
        .padding(.horizontal, 2.4)
        .background(Capsule().fill(Tokens.Surface.segmented.color).padding(.vertical, 8.5))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Contrast method")
    }
}

/// Track (5.12pt, inset 4pt), fill `min(1, ratio/12)`, and AA 4.5 / AAA 7 tick buttons (PM §8.11).
private struct ContrastMeter: View {
    let ratio: Double
    let onJump: (Double) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                Capsule().fill(Tokens.Surface.track.color)
                    .frame(width: width, height: Tokens.Size.contrastTrack)
                Capsule().fill(Tokens.Selected.segment.color)
                    .frame(width: width * ColorMath.Meter.fill(ratio), height: Tokens.Size.contrastTrack)
                    .animation(Motion.colorChange, value: ratio)
                tick(name: "AA", target: ColorMath.aa, at: ColorMath.Meter.aaPosition * width)
                tick(name: "AAA", target: ColorMath.aaa, at: ColorMath.Meter.aaaPosition * width)
            }
        }
        .frame(height: Tokens.Size.contrastTrack + (dynamicTypeSize.isAccessibilitySize ? 16 : 32))
        .padding(.horizontal, 4)
        .accessibilityElement(children: .contain)
    }

    /// A 1pt line from 4.8pt above the track plus its label, inside a 44pt-wide tappable column.
    private func tick(name: String, target: Double, at x: CGFloat) -> some View {
        let passes = ratio >= target
        let value = target == ColorMath.aa ? "4.5" : "7"
        return Button {
            onJump(target)
        } label: {
            // 8pt (web 5.6): keeps the light tick line clear of the label; the accessibility audit read
            // the line as the label's background when they touched.
            VStack(spacing: 8) {
                Rectangle().fill(Tokens.Line.tick.color)
                    .frame(width: Tokens.Size.tickWidth, height: Tokens.Size.tickHeight)
                if !dynamicTypeSize.isAccessibilitySize {
                    TickLegend(name: name, value: value, passes: passes)
                }
            }
            .frame(minWidth: Tokens.Size.minHitTarget, minHeight: Tokens.Size.minHitTarget, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(x: x, y: -4.8 + Tokens.Size.minHitTarget / 2)
        .accessibilityLabel("Jump to WCAG \(name) contrast")
        .accessibilityValue(passes ? "passes" : "fails")
        .accessibilityIdentifier("tick.\(name)")
    }
}

/// "✓ AA 4.5": the glyph is always shown, so pass/fail never depends on color
/// (Differentiate Without Color, ios.md §11).
private struct TickLegend: View {
    let name: String
    let value: String
    let passes: Bool

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: passes ? "checkmark" : "xmark")
                .imageScale(.small)
                .font(Typography.tickLabel.font.weight(.bold))
            Text(verbatim: "\(name) \(value)")
                .typeStyle(Typography.tickLabel)
        }
        .foregroundStyle(Tokens.Text.tick.color)
        .fixedSize()
        .accessibilityHidden(true)   // the tick buttons carry "passes"/"fails"
    }
}
