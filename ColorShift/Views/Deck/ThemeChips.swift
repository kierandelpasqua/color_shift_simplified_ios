import SwiftUI

/// "All" + the six themes, multi-select (PM §9). Selected chips play the wave pulse in sync (M3).
struct ThemeChips: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Tokens.Spacing.chipGap) {
                ThemeChip(title: "All", isSelected: model.selectedThemes.isEmpty) {
                    model.toggleTheme(nil)
                }
                ForEach(Theme.allCases, id: \.self) { theme in
                    ThemeChip(title: theme.title, isSelected: model.selectedThemes.contains(theme)) {
                        model.toggleTheme(theme)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Photo themes")
    }
}

private struct ThemeChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(title)
                .typeStyle(Typography.chip)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle((isSelected ? Tokens.Surface.canvas : Tokens.Text.chip).color)
                .padding(.vertical, 7.68)
                .padding(.horizontal, 11.2)
                .background {
                    Capsule().fill(isSelected ? Tokens.Selected.chipFill.color : .clear)
                }
                .overlay {
                    if isSelected && Motion.chipWaveEnabled(reduceMotion: reduceMotion) {
                        ChipWave().clipShape(Capsule()).allowsHitTesting(false)
                    }
                }
                .overlay {
                    Capsule().strokeBorder((isSelected ? Tokens.Selected.chipFill : Tokens.Line.chip).color, lineWidth: 1)
                }
                // 44pt hit area around the web-sized capsule (NFR4).
                .frame(minHeight: Tokens.Size.minHitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("chip.\(title)")
    }
}

/// The selected-chip shimmer (web `@keyframes chip-wave`, PM §12 M3): a 36pt band sweeping left to right
/// over the first 19% of a 5 s cycle. Driven by the wall clock, so every selected chip runs in sync (D6).
struct ChipWave: View {
    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: Motion.chipWavePeriod) / Motion.chipWavePeriod
                let state = Self.state(at: phase, width: proxy.size.width)
                LinearGradient(
                    colors: [Tokens.Effect.chipWavePeak.opacity(0).color, Tokens.Effect.chipWavePeak.color,
                             Tokens.Effect.chipWavePeak.opacity(0).color],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: Motion.chipWaveBandWidth)
                .offset(x: state.x)
                .opacity(state.opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .accessibilityHidden(true)
    }

    /// Band position and opacity at a cycle phase 0…1. CSS applies ease-in-out between keyframes:
    /// `left` −36 → 100% over 0…19%; opacity 0 → 1 by 2.8%, held to 15%, → 0 by 19%.
    static func state(at phase: Double, width: CGFloat) -> (x: CGFloat, opacity: Double) {
        let sweepEnd = Motion.chipWaveSweepEnd
        guard phase < sweepEnd else { return (width, 0) }
        let x = -Motion.chipWaveBandWidth + (width + Motion.chipWaveBandWidth) * easeInOut(phase / sweepEnd)
        let opacity: Double
        if phase < Motion.chipWaveFadeInEnd {
            opacity = easeInOut(phase / Motion.chipWaveFadeInEnd)
        } else if phase < Motion.chipWaveHoldEnd {
            opacity = 1
        } else {
            opacity = 1 - easeInOut((phase - Motion.chipWaveHoldEnd) / (sweepEnd - Motion.chipWaveHoldEnd))
        }
        return (x, opacity)
    }

    /// CSS `ease-in-out` = cubic-bezier(0.42, 0, 0.58, 1).
    static func easeInOut(_ t: Double) -> Double {
        UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.42, y: 0), endControlPoint: UnitPoint(x: 0.58, y: 1))
            .value(at: t)
    }
}
