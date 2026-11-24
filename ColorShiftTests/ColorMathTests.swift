import Testing
@testable import ColorShift

private func c(_ hex: String) -> SRGB8 { SRGB8(hex: hex)! }

struct ColorMathTests {

    // MARK: PM §8.12 vectors

    @Test(arguments: [("#FFFFFF", 1.0), ("#000000", 0.0), ("#F2D27A", 0.664), ("#1F3A5F", 0.041), ("#111214", 0.006)])
    func luminance(hex: String, expected: Double) {
        #expect(abs(ColorMath.luminance(c(hex)) - expected) < 0.0005)
    }

    @Test(arguments: [
        ("#FFFFFF", "#000000", 21.000),
        ("#F2D27A", "#1F3A5F", 7.806),
        ("#F4C6D9", "#16172B", 11.687),
        ("#777980", "#111214", 4.312),
    ])
    func contrast(a: String, b: String, expected: Double) {
        #expect(abs(ColorMath.contrast(c(a), c(b)) - expected) < 0.0005)
        #expect(ColorMath.contrast(c(a), c(b)) == ColorMath.contrast(c(b), c(a)))
    }

    @Test(arguments: [
        ("#8899AA", "#1F3A5F", 4.5, "#97A6B5", 4.614),
        ("#8899AA", "#1F3A5F", 7.0, "#C3CCD5", 7.064),
        ("#8899AA", "#F4F4EF", 4.5, "#5D7083", 4.630),
        ("#556677", "#FFFFFF", 7.0, "#4A5968", 7.192),
    ])
    func tune(color: String, fixed: String, target: Double, expected: String, achieved: Double) {
        let result = ColorMath.tune(c(color), against: c(fixed), target: target)
        #expect(result.color.hex == expected)
        #expect(result.reachedTarget)
        #expect(abs(ColorMath.contrast(result.color, c(fixed)) - achieved) < 0.0005)
    }

    @Test(arguments: [
        (0.67, 39, 47), (0.85, 44, 42), (1.2, 48, 38), (1.33, 48, 38), (1.45, 50, 35), (1.56, 50, 35),
    ])
    func layoutShares(aspect: Double, desktop: Int, mobile: Int) {
        let shares = ColorMath.layoutShares(aspect: aspect)
        #expect(shares.desktop == desktop && shares.mobile == mobile)
    }

    // MARK: Tune edge cases (ios.md §14)

    @Test func tuneReportsMissWhenTargetIsUnreachable() {
        // Mid-gray against mid-gray: even 0% or 100% lightness can't reach 7:1.
        let result = ColorMath.tune(c("#777777"), against: c("#777777"), target: 7)
        #expect(!result.reachedTarget)
        #expect(ColorMath.contrast(result.color, c("#777777")) < 7)
        // Against a dark fixed color it lightens all the way to white.
        #expect(result.color == c("#FFFFFF"))
    }

    @Test(arguments: [4.5, 7.0])
    func tuneOnlyMovesLightness(target: Double) {
        // Every candidate is built from the start color's integer h and s with a new l. (Reading HSL back
        // from the 8-bit result can re-round s, so compare against the rebuild, not `result.color.hsl`.)
        let start = c("#8899AA")
        let result = ColorMath.tune(start, against: c("#1F3A5F"), target: target)
        let hsl = start.hsl
        #expect((0...100).contains { SRGB8(hsl: HSL(h: hsl.h, s: hsl.s, l: $0)) == result.color })
    }

    @Test func tuneOfAlreadyPassingColorReturnsItsHSLRebuild() {
        // Web parity: step 0 is hslToHex(rgbToHsl(color)), which can drift (PM §8.12 round trip).
        let result = ColorMath.tune(c("#F2D27A"), against: c("#1F3A5F"), target: 4.5)
        #expect(result.reachedTarget)
        #expect(result.color.hex == "#F2D178")
    }

    // MARK: Meter (PM §8.11)

    @Test func meterGeometry() {
        #expect(ColorMath.Meter.aaPosition == 0.375)
        #expect(abs(ColorMath.Meter.aaaPosition - 0.5833) < 0.0001)
        #expect(ColorMath.Meter.fill(6) == 0.5)
        #expect(ColorMath.Meter.fill(21) == 1)
        #expect(ColorMath.Meter.nextTarget(for: 4.49) == 4.5)
        #expect(ColorMath.Meter.nextTarget(for: 4.5) == 7)
        #expect(ColorMath.Meter.nextTarget(for: 9) == 7)
    }
}
