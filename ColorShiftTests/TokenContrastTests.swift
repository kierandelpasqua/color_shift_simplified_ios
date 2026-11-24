import Testing
@testable import ColorShift

/// Composites a swatch over an opaque background (source-over in sRGB, like the browser).
private func composite(_ top: Swatch, over bottom: (Double, Double, Double)) -> (Double, Double, Double) {
    let a = top.opacity
    return (Double(top.red) * a + bottom.0 * (1 - a),
            Double(top.green) * a + bottom.1 * (1 - a),
            Double(top.blue) * a + bottom.2 * (1 - a))
}

/// Rounds a composited color to 8 bits, as the screen would show it.
private func srgb8(_ c: (Double, Double, Double)) -> SRGB8 {
    func q(_ v: Double) -> UInt8 { UInt8(min(255, max(0, v.rounded()))) }
    return SRGB8(r: q(c.0), g: q(c.1), b: q(c.2))
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
        let ratio = ColorMath.contrast(srgb8(text), srgb8(background))
        #expect(ratio >= 4.5, "\(pair.name): \(ratio)")
    }

    @Test func mutedFollowsIncreaseContrast() {
        #expect(Tokens.Text.muted(.standard) == Tokens.Text.muted)
        #expect(Tokens.Text.muted(.increased) == Tokens.Text.mutedIncreased)
    }

    @Test func typeScaleMeetsMinimumSize() {
        #expect(Typography.all.allSatisfy { $0.size >= 11 })
    }
}
