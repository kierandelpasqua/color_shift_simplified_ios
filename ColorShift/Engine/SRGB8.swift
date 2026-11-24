import SwiftUI

/// An 8-bit sRGB color: exactly what a `#RRGGBB` hex string holds. The app stores colors as this and
/// derives hex and HSL from it (ios.md §5 State), so values never drift unless a slider actually moves.
nonisolated struct SRGB8: Hashable, Sendable {
    var r: UInt8
    var g: UInt8
    var b: UInt8

    init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    // MARK: Hex (PM §8.1–8.2)

    /// Parses `#RRGGBB` or `RRGGBB`, case-insensitive. Returns nil for anything else (unlike the web's
    /// `hexToRgb`, which doesn't validate; the web validates share links separately, PM §14).
    init?(hex: String) {
        var bytes = Array(hex.utf8)
        if bytes.first == UInt8(ascii: "#") { bytes.removeFirst() }
        guard bytes.count == 6 else { return nil }
        var values = [UInt8]()
        values.reserveCapacity(6)
        for byte in bytes {
            guard let value = Self.hexValue(byte) else { return nil }
            values.append(value)
        }
        r = values[0] << 4 | values[1]
        g = values[2] << 4 | values[3]
        b = values[4] << 4 | values[5]
    }

    /// `#RRGGBB`, uppercase (the web's `rgbToHex` output).
    var hex: String { "#" + hexDigits }

    /// `RRGGBB`, uppercase, no `#` (the share-link form, PM §14).
    var hexDigits: String { Self.hexByte(r) + Self.hexByte(g) + Self.hexByte(b) }

    // MARK: HSL (PM §8.3–8.4, §8.13)

    /// Integer-rounded HSL, like the web's `rgbToHsl`: h 0–359, s 0–100, l 0–100.
    var hsl: HSL {
        let r = Double(r) / 255, g = Double(g) / 255, b = Double(b) / 255
        let maxC = max(r, g, b), minC = min(r, g, b)
        let d = maxC - minC
        let l = (maxC + minC) / 2
        let s = d == 0 ? 0 : d / (1 - abs(2 * l - 1))
        var h = 0.0
        if d != 0 {
            if maxC == r {
                h = ((g - b) / d).truncatingRemainder(dividingBy: 6)   // JS %: sign of the dividend
            } else if maxC == g {
                h = (b - r) / d + 2
            } else {
                h = (r - g) / d + 4
            }
        }
        return HSL(
            h: Int(Self.jsRound((h * 60 + 360).truncatingRemainder(dividingBy: 360))),
            s: Int(Self.jsRound(s * 100)),
            l: Int(Self.jsRound(l * 100))
        )
    }

    /// The web's `hslToHex`, including its rounding. Hue is used as given (the web's sliders send 0–360;
    /// 360 lands in the last sector and gives the same color as 0). Channels are clamped to 0–255 after
    /// rounding, which only matters for out-of-range input the web never produces.
    init(hsl: HSL) {
        let s = Double(hsl.s) / 100, l = Double(hsl.l) / 100, h = Double(hsl.h)
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        let (r1, g1, b1): (Double, Double, Double) =
            h < 60 ? (c, x, 0)
            : h < 120 ? (x, c, 0)
            : h < 180 ? (0, c, x)
            : h < 240 ? (0, x, c)
            : h < 300 ? (x, 0, c)
            : (c, 0, x)
        r = Self.channel((r1 + m) * 255)
        g = Self.channel((g1 + m) * 255)
        b = Self.channel((b1 + m) * 255)
    }

    // MARK: SwiftUI

    var color: Color {
        Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    // MARK: Helpers

    /// JavaScript `Math.round`: halves round toward +∞ (PM §8.13).
    static func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }

    private static func channel(_ value: Double) -> UInt8 {
        UInt8(min(255, max(0, jsRound(value))))
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): byte - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"): byte - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): byte - UInt8(ascii: "A") + 10
        default: nil
        }
    }

    private static let digits = Array("0123456789ABCDEF")

    private static func hexByte(_ value: UInt8) -> String {
        String([digits[Int(value >> 4)], digits[Int(value & 0x0F)]])
    }
}

/// Integer HSL as the web uses it (h degrees, s and l percent).
nonisolated struct HSL: Hashable, Sendable {
    var h: Int
    var s: Int
    var l: Int
}

extension SRGB8: CustomStringConvertible {
    nonisolated var description: String { hex }
}

/// Encoded as a `"#RRGGBB"` string, so fixtures and stored values read like the web's.
extension SRGB8: Codable {
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = SRGB8(hex: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid hex color: \(string)")
        }
        self = value
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}
