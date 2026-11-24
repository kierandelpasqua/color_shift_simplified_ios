import SwiftUI

/// Every animation constant in the app, mirroring the web's shipped defaults (`src/motionConfig.ts`,
/// `index.css`; PM §12, ios.md §9). Nothing else should hard-code a duration or curve.
/// Each animation has a Reduce Motion variant; call sites pass `accessibilityReduceMotion`.
nonisolated enum Motion {

    // MARK: M1 Drawer (spring 340 / 36 / 1.7, ~2.9% overshoot)

    static let drawerStiffness: Double = 340
    static let drawerDamping: Double = 36
    static let drawerMass: Double = 1.7

    static func drawer(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .interpolatingSpring(mass: drawerMass, stiffness: drawerStiffness, damping: drawerDamping)
    }

    // MARK: M2 Photo reveal (opacity 0→1, scale 1.04→1, blur 8→0, 600 ms)

    static let revealDuration: Double = 0.6
    static let revealStartOpacity: Double = 0
    static let revealStartScale: CGFloat = 1.04
    static let revealStartBlur: CGFloat = 8

    /// Under Reduce Motion the reveal is a short fade only: callers skip the scale and blur.
    static func reveal(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.2)
            : .timingCurve(0.22, 0.76, 0.32, 1, duration: revealDuration)
    }

    // MARK: M3 Chip wave (selected chips; none under Reduce Motion)

    /// One sweep cycle. Phases are fractions of the cycle, from `@keyframes chip-wave`:
    /// the 36pt band moves from −36pt to the chip's trailing edge over 0…19%, fading in by 2.8%,
    /// holding to 15% and out by 19%, then rests until 100%. CSS applies ease-in-out per keyframe segment.
    /// The band is a gradient `canvas @0 → canvas @0.08 → canvas @0` (`Tokens.Effect.chipWavePeak`).
    static let chipWavePeriod: Double = 5
    static let chipWaveBandWidth: CGFloat = 36
    static let chipWaveFadeInEnd: Double = 0.028
    static let chipWaveHoldEnd: Double = 0.15
    static let chipWaveSweepEnd: Double = 0.19

    static func chipWaveEnabled(reduceMotion: Bool) -> Bool { !reduceMotion }

    // MARK: M4 Specimen colors / M6 toast (180 ms CSS `ease`)

    /// CSS `ease` = cubic-bezier(0.25, 0.1, 0.25, 1).
    static let colorChange: Animation = .timingCurve(0.25, 0.1, 0.25, 1, duration: 0.18)

    static let toastAnimation: Animation = .timingCurve(0.25, 0.1, 0.25, 1, duration: 0.18)
    static let toastVisibleDuration: Duration = .milliseconds(1600)
    static let toastRise: CGFloat = 16

    /// Under Reduce Motion the toast fades without rising.
    static func toastTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: toastRise))
    }

    // MARK: M5 Pressed state (replaces the web's hover)

    static let pressedScale: CGFloat = 0.96
    static let pressAnimation: Animation = .timingCurve(0.25, 0.1, 0.25, 1, duration: 0.18)
}
