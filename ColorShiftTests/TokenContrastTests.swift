import Foundation
import Testing
@testable import ColorShift

/// TEMPORARY WCAG 2.x helper (PM §8.5–8.6). Replace with `ColorMath` in T-011.
private enum TemporaryWCAG {
    static func luminance(_ r: Double, _ g: Double, _ b: Double) -> Double {
        func lin(_ c: Double) -> Double {
            let v = c / 255
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    static func contrast(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        let la = luminance(a.0, a.1, a.2), lb = luminance(b.0, b.1, b.2)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}

/// Composites a swatch over an opaque background (source-over in sRGB, like the browser).
private func composite(_ top: Swatch, over bottom: (Double, Double, Double)) -> (Double, Double, Double) {
    let a = top.opacity
    return (Double(top.red) * a + bottom.0 * (1 - a),
            Double(top.green) * a + bottom.1 * (1 - a),
            Double(top.blue) * a + bottom.2 * (1 - a))
}

private func rgb(_ s: Swatch) -> (Double, Double, Double) { composite(s, over: (0, 0, 0)) }

nonisolated struct TextPair: CustomTestStringConvertible, Sendable {
    let name: String
    let text: Swatch
    let background: Swatch
    /// The opaque backdrop behind a translucent `background` (worst case for the credit chip: a white photo).
    var backdrop: Swatch? = nil

    var testDescription: String { name }
}

/// Every text/background token pair used in the UI (PM §9–10, ios.md §8).
nonisolated let textPairs: [TextPair] = [
    .init(name: "primary on canvas", text: Tokens.Text.primary, background: Tokens.Surface.canvas),
    .init(name: "deck on canvas", text: Tokens.Text.deck, background: Tokens.Surface.canvas),
    .init(name: "muted on canvas", text: Tokens.Text.muted, background: Tokens.Surface.canvas),
    .init(name: "muted (Increase Contrast) on canvas", text: Tokens.Text.mutedIncreased, background: Tokens.Surface.canvas),
    .init(name: "subtle on canvas", text: Tokens.Text.subtle, background: Tokens.Surface.canvas),
    .init(name: "tick on canvas", text: Tokens.Text.tick, background: Tokens.Surface.canvas),
    .init(name: "chip on canvas", text: Tokens.Text.chip, background: Tokens.Surface.canvas),
    .init(name: "selected chip", text: Tokens.Surface.canvas, background: Tokens.Selected.chipFill),
    .init(name: "inactive segment", text: Tokens.Text.chip, background: Tokens.Surface.segmented),
    .init(name: "active segment", text: Tokens.Surface.canvas, background: Tokens.Selected.segment),
    .init(name: "button", text: Tokens.Text.button, background: Tokens.Surface.button),
    .init(name: "toast", text: Tokens.Text.toast, background: Tokens.Surface.button),
    .init(name: "swap icon on canvas", text: Tokens.Icon.swap, background: Tokens.Surface.canvas),
    .init(name: "credit name over white photo", text: Tokens.Text.creditName, background: Tokens.Surface.credit,
          backdrop: Swatch(rgb: 0xFFFFFF)),
    .init(name: "credit label over white photo", text: Tokens.Text.creditLabel, background: Tokens.Surface.credit,
          backdrop: Swatch(rgb: 0xFFFFFF)),
    .init(name: "credit label over black photo", text: Tokens.Text.creditLabel, background: Tokens.Surface.credit,
          backdrop: Swatch(rgb: 0x000000)),
]

struct TokenContrastTests {
    @Test(arguments: textPairs)
    func textPairMeetsAA(_ pair: TextPair) {
        let backdrop = pair.backdrop.map(rgb) ?? (0, 0, 0)
        let background = composite(pair.background, over: backdrop)
        let text = composite(pair.text, over: background)
        let ratio = TemporaryWCAG.contrast(text, background)
        #expect(ratio >= 4.5, "\(pair.name): \(ratio)")
    }

    @Test func helperMatchesWebVectors() {
        // PM §8.12: sanity-check the temporary helper itself.
        #expect(abs(TemporaryWCAG.contrast((255, 255, 255), (0, 0, 0)) - 21) < 0.001)
        #expect(abs(TemporaryWCAG.contrast((0x77, 0x79, 0x80), (0x11, 0x12, 0x14)) - 4.312) < 0.001)
        #expect(abs(TemporaryWCAG.contrast((0xF2, 0xD2, 0x7A), (0x1F, 0x3A, 0x5F)) - 7.806) < 0.001)
    }

    @Test func mutedFollowsIncreaseContrast() {
        #expect(Tokens.Text.muted(.standard) == Tokens.Text.muted)
        #expect(Tokens.Text.muted(.increased) == Tokens.Text.mutedIncreased)
    }

    @Test func typeScaleMeetsMinimumSize() {
        #expect(Typography.all.allSatisfy { $0.size >= 11 })
    }
}
