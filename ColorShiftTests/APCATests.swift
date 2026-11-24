import Testing
@testable import ColorShift

private func c(_ hex: String) -> SRGB8 { SRGB8(hex: hex)! }

struct APCATests {

    /// ios.md §7 vectors; the first four match the published APCA reference values.
    @Test(arguments: [
        ("#888888", "#FFFFFF", 63.056),
        ("#FFFFFF", "#888888", -68.541),
        ("#000000", "#AAAAAA", 58.146),
        ("#AAAAAA", "#000000", -56.241),
        ("#000000", "#FFFFFF", 106.041),
        ("#FFFFFF", "#000000", -107.885),
        ("#F4C6D9", "#16172B", -78.254),
        ("#F2D27A", "#1F3A5F", -73.164),
        ("#777980", "#111214", -30.957),
    ])
    func vectors(text: String, background: String, expected: Double) {
        #expect(abs(APCA.lc(text: c(text), background: c(background)) - expected) < 0.001)
    }

    @Test func edgeCases() {
        #expect(APCA.lc(text: c("#808080"), background: c("#808080")) == 0)
        #expect(APCA.contrast(textY: .nan, backgroundY: 1) == 0)
        #expect(APCA.contrast(textY: -0.1, backgroundY: 1) == 0)
        #expect(APCA.contrast(textY: 0, backgroundY: 1.2) == 0)
    }

    @Test func lowContrastClipsToZero() {
        // |SAPC| below 0.1 (Lc 10) reports 0 in both polarities.
        #expect(APCA.lc(text: c("#777777"), background: c("#7A7A7A")) == 0)
        #expect(APCA.lc(text: c("#7A7A7A"), background: c("#777777")) == 0)
    }

    @Test func displayValueIsRoundedMagnitude() {
        #expect(APCA.displayValue(-73.164) == 73)
        #expect(APCA.displayValue(63.5) == 64)
        #expect(APCA.displayValue(-63.5) == 64)
        #expect(APCA.displayValue(0) == 0)
    }
}
