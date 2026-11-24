import Foundation

/// APCA 0.0.98G-4g contrast (Lc), ported from Myndex/apca-w3 `src/apca-w3.js` (Beta 0.1.9 W3,
/// "G-4g constants for use with 2.4 exponent"). Constants are copied verbatim; see
/// research/color-apca-image-sampling.md. The apca-w3 license concern was reviewed by the owner (ios.md I4).
///
/// Replaces the web's `apcaApprox` (PM §8.7). Results are **signed**: positive = dark text on a light
/// background, negative = light text on a dark background. Argument order matters (text, then background).
nonisolated enum APCA {
    static let mainTRC = 2.4
    static let sRco = 0.2126729, sGco = 0.7151522, sBco = 0.0721750
    static let normBG = 0.56, normTXT = 0.57, revTXT = 0.62, revBG = 0.65
    static let blkThrs = 0.022, blkClmp = 1.414
    static let scaleBoW = 1.14, scaleWoB = 1.14
    static let loBoWoffset = 0.027, loWoBoffset = 0.027
    static let deltaYmin = 0.0005, loClip = 0.1

    /// APCA screen luminance: a simple 2.4 power curve, **not** the WCAG piecewise curve.
    static func y(_ color: SRGB8) -> Double {
        func e(_ v: UInt8) -> Double { pow(Double(v) / 255, mainTRC) }
        return sRco * e(color.r) + sGco * e(color.g) + sBco * e(color.b)
    }

    /// Signed Lc from screen luminances. Returns 0 for out-of-range input, like apca-w3.
    static func contrast(textY: Double, backgroundY: Double) -> Double {
        guard !textY.isNaN, !backgroundY.isNaN,
              min(textY, backgroundY) >= 0, max(textY, backgroundY) <= 1.1 else { return 0 }
        func softClamp(_ y: Double) -> Double { y > blkThrs ? y : y + pow(blkThrs - y, blkClmp) }
        let text = softClamp(textY), background = softClamp(backgroundY)
        guard abs(background - text) >= deltaYmin else { return 0 }
        let output: Double
        if background > text {                       // BoW: dark text on light
            let sapc = (pow(background, normBG) - pow(text, normTXT)) * scaleBoW
            output = sapc < loClip ? 0 : sapc - loBoWoffset
        } else {                                     // WoB: light text on dark
            let sapc = (pow(background, revBG) - pow(text, revTXT)) * scaleWoB
            output = sapc > -loClip ? 0 : sapc + loWoBoffset
        }
        return output * 100
    }

    /// Signed Lc for a text color on a background color.
    static func lc(text: SRGB8, background: SRGB8) -> Double {
        contrast(textY: y(text), backgroundY: y(background))
    }

    /// The number shown in the readout: `round(|Lc|)`, matching the web's unsigned "71 Lc" style (ios.md §7).
    static func displayValue(_ lc: Double) -> Int { Int(SRGB8.jsRound(abs(lc))) }
}
