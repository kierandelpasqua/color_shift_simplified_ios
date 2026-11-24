import Foundation
import Testing
import UIKit
@testable import ColorShift

private func c(_ hex: String) -> SRGB8 { SRGB8(hex: hex)! }

struct SRGB8Tests {

    // MARK: PM §8.12 vectors

    @Test(arguments: [
        ("#F2D27A", HSL(h: 44, s: 82, l: 71)),
        ("#1F3A5F", HSL(h: 215, s: 51, l: 25)),
        ("#16172B", HSL(h: 237, s: 32, l: 13)),
        ("#F4C6D9", HSL(h: 335, s: 68, l: 87)),
        ("#808080", HSL(h: 0, s: 0, l: 50)),
        ("#FF0000", HSL(h: 0, s: 100, l: 50)),
    ])
    func rgbToHSL(hex: String, expected: HSL) {
        #expect(c(hex).hsl == expected)
    }

    @Test(arguments: [
        (HSL(h: 45, s: 82, l: 71), "#F2D378"),
        (HSL(h: 214, s: 51, l: 25), "#1F3B60"),
        (HSL(h: 0, s: 100, l: 50), "#FF0000"),
        (HSL(h: 200, s: 0, l: 50), "#808080"),
    ])
    func hslToHex(hsl: HSL, expected: String) {
        #expect(SRGB8(hsl: hsl).hex == expected)
    }

    @Test(arguments: [("#F2D27A", "#F2D178"), ("#1F3A5F", "#1F3A60")])
    func hslRoundTripDriftMatchesWeb(hex: String, expected: String) {
        #expect(SRGB8(hsl: c(hex).hsl).hex == expected)
    }

    @Test func hexToRGB() {
        #expect(c("#F2D27A") == SRGB8(r: 0xF2, g: 0xD2, b: 0x7A))
        #expect(c("1f3a5f") == SRGB8(r: 0x1F, g: 0x3A, b: 0x5F))
    }

    // MARK: Parsing and formatting

    @Test(arguments: ["#f2d27a", "F2D27A", "f2D27a", "#F2D27A"])
    func parsesWithOrWithoutHashAnyCase(_ input: String) {
        #expect(SRGB8(hex: input)?.hex == "#F2D27A")
    }

    @Test(arguments: ["", "#", "F2D27", "#F2D27", "F2D27A0", "##F2D27A", "GGGGGG", " F2D27A", "F2D27A ",
                      "#F2 27A", "+2D27A", "-2D27A", "0xF2D2", "#FFF", "F2D27Ａ", "F2D2７A"])
    func rejectsInvalidHex(_ input: String) {
        #expect(SRGB8(hex: input) == nil)
    }

    @Test func formatsUppercaseZeroPadded() {
        let color = SRGB8(r: 0, g: 0x0A, b: 0xFF)
        #expect(color.hex == "#000AFF")
        #expect(color.hexDigits == "000AFF")
        #expect(color.description == "#000AFF")
    }

    @Test func roundTripsAll12BitGridColorsThroughHex() {
        let steps = (0...15).map { UInt8($0 * 0x11) }
        var count = 0
        for r in steps {
            for g in steps {
                for b in steps {
                    let color = SRGB8(r: r, g: g, b: b)
                    #expect(SRGB8(hex: color.hex) == color)
                    #expect(SRGB8(hex: color.hexDigits.lowercased()) == color)
                    count += 1
                }
            }
        }
        #expect(count == 4096)
    }

    // MARK: HSL edge cases

    @Test func hue360MatchesHue0() {
        #expect(SRGB8(hsl: HSL(h: 360, s: 100, l: 50)) == SRGB8(hsl: HSL(h: 0, s: 100, l: 50)))
    }

    @Test func negativeHueSectorUsesDividendSignedModulo() {
        // max = r with g < b gives a negative ((g − b)/d) % 6, which the web shifts by +360.
        #expect(c("#FF0080").hsl == HSL(h: 330, s: 100, l: 50))
    }

    @Test func hslStaysInRangeForGrid() {
        let steps = (0...15).map { UInt8($0 * 0x11) }
        for r in steps { for g in steps { for b in steps {
            let hsl = SRGB8(r: r, g: g, b: b).hsl
            #expect((0...359).contains(hsl.h) && (0...100).contains(hsl.s) && (0...100).contains(hsl.l))
        } } }
    }

    // MARK: Codable and Color

    @Test func codableUsesHexString() throws {
        let data = try JSONEncoder().encode([c("#1f3a5f")])
        #expect(String(decoding: data, as: UTF8.self) == ##"["#1F3A5F"]"##)
        #expect(try JSONDecoder().decode([SRGB8].self, from: data) == [c("#1F3A5F")])
        #expect(throws: DecodingError.self) { try JSONDecoder().decode([SRGB8].self, from: Data(#"["nope"]"#.utf8)) }
    }

    @Test func colorConversionIsSRGB() {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(c("#F2D27A").color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #expect(abs(red * 255 - 0xF2) < 0.01)
        #expect(abs(green * 255 - 0xD2) < 0.01)
        #expect(abs(blue * 255 - 0x7A) < 0.01)
        #expect(alpha == 1)
    }
}
