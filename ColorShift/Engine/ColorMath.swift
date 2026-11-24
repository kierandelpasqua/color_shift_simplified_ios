import Foundation

/// The web's color math (PM §8.5, 8.6, 8.8, 8.10, 8.11), ported verbatim except where noted.
/// APCA lives in `APCA.swift`.
nonisolated enum ColorMath {

    /// WCAG AA and AAA thresholds for body text.
    static let aa: Double = 4.5
    static let aaa: Double = 7

    // MARK: WCAG (PM §8.5–8.6)

    /// WCAG 2.x relative luminance, 0…1.
    static func luminance(_ color: SRGB8) -> Double {
        func linear(_ channel: UInt8) -> Double {
            let v = Double(channel) / 255
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
    }

    /// WCAG contrast ratio, 1…21, order-independent.
    static func contrast(_ a: SRGB8, _ b: SRGB8) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    // MARK: Tune (PM §8.8)

    struct TuneResult: Hashable, Sendable {
        var color: SRGB8
        /// False when 0% or 100% lightness still falls short of the target (the web misses silently; ios.md §14).
        var reachedTarget: Bool
    }

    /// Moves only `color`'s HSL lightness, toward dark against a light `fixed` color and toward light
    /// against a dark one, one step at a time until the contrast reaches `target`. Like the web, even the
    /// first candidate is rebuilt from integer HSL, so the result can differ slightly from `color` itself.
    static func tune(_ color: SRGB8, against fixed: SRGB8, target: Double = aa) -> TuneResult {
        let hsl = color.hsl
        let direction = luminance(fixed) > 0.45 ? -1 : 1
        var best = color
        for step in 0...100 {
            let lightness = max(0, min(100, hsl.l + direction * step))
            let candidate = SRGB8(hsl: HSL(h: hsl.h, s: hsl.s, l: lightness))
            best = candidate
            if contrast(candidate, fixed) >= target {
                return TuneResult(color: candidate, reachedTarget: true)
            }
        }
        return TuneResult(color: best, reachedTarget: false)
    }

    // MARK: Formatting

    /// The WCAG readout and Markdown value, e.g. `7.81` (the web's `ratio.toFixed(2)`).
    static func formatRatio(_ ratio: Double) -> String { jsToFixed(ratio, digits: 2) }

    /// JavaScript `Number.prototype.toFixed` for non-negative finite values: rounds the **exact** binary
    /// value, and exact ties round up. (`String(format: "%.2f")` rounds ties to even: 1.125 → "1.12", JS "1.13".)
    static func jsToFixed(_ value: Double, digits: Int) -> String {
        precondition(value >= 0 && value.isFinite && digits >= 0)
        // 1074 digits would cover every double; values here are < 1e3, so 80 fraction digits are exact.
        let exact = String(format: "%.80f", value)
        let dot = exact.firstIndex(of: ".")!
        var whole = Array(exact[..<dot]) + Array(exact[exact.index(after: dot)...].prefix(digits))
        let next = exact[exact.index(after: dot)...].dropFirst(digits).first ?? "0"
        if next >= "5" {
            var i = whole.count - 1
            while i >= 0 {
                if whole[i] == "9" { whole[i] = "0"; i -= 1 } else {
                    whole[i] = Character(String(whole[i].wholeNumberValue! + 1)); break
                }
            }
            if i < 0 { whole.insert("1", at: 0) }
        }
        let intCount = whole.count - digits
        let intPart = String(whole[..<intCount])
        return digits == 0 ? intPart : intPart + "." + String(whole[intCount...])
    }

    // MARK: Layout (PM §8.10)

    /// Photo share of the canvas, in percent, by photo aspect (width / height).
    /// iOS uses `mobile` (photo height in the portrait layout); `desktop` is kept for parity.
    static func layoutShares(aspect: Double) -> (desktop: Int, mobile: Int) {
        if aspect < 0.85 { return (39, 47) }
        if aspect < 1.2 { return (44, 42) }
        if aspect < 1.45 { return (48, 38) }
        return (50, 35)
    }

    // MARK: Contrast meter (PM §8.11)

    /// The meter always shows WCAG, even in APCA mode.
    enum Meter {
        /// The ratio at a full meter.
        static let scale: Double = 12

        /// Fill fraction, 0…1: `min(1, ratio / 12)`.
        static func fill(_ ratio: Double) -> Double { min(1, ratio / scale) }

        /// Tick positions as fractions of the track: AA 37.5%, AAA 58.3%.
        static let aaPosition = aa / scale
        static let aaaPosition = aaa / scale

        /// The Jump button's target: AA below 4.5, otherwise AAA (web `next-pass`).
        static func nextTarget(for ratio: Double) -> Double { ratio < aa ? aa : aaa }
    }
}
