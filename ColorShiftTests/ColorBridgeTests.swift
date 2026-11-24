import Testing
import UIKit
@testable import ColorShift

struct ColorBridgeTests {
    @Test func displayP3RedClampsToSRGBRed() {
        // P3 red lies outside sRGB: extended-sRGB components are about (1.09, −0.23, −0.15).
        let p3Red = UIColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1)
        #expect(SRGB8(p3Red) == SRGB8(r: 255, g: 0, b: 0))
    }

    @Test func displayP3InGamutColorConverts() {
        // P3 (0.5, 0.5, 0.5) is a neutral gray; P3 and sRGB share the transfer curve and white point.
        let gray = UIColor(displayP3Red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        #expect(SRGB8(gray) == SRGB8(r: 128, g: 128, b: 128))
    }

    @Test func sRGBRoundTripsExactly() {
        let steps = (0...15).map { UInt8($0 * 0x11) }
        for r in steps { for g in steps { for b in steps {
            let c = SRGB8(r: r, g: g, b: b)
            #expect(SRGB8(c.uiColor) == c)
        } } }
    }
}
