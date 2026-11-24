import UIKit

extension SRGB8 {
    /// Converts any UIColor (e.g. a Display P3 color from the system picker) to 8-bit sRGB.
    /// `getRed` returns extended-sRGB components, which go below 0 or above 1 outside the sRGB gamut;
    /// those are clamped to the sRGB edge (ios.md §6), then rounded like the web's `rgbToHex`.
    nonisolated init(_ color: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ v: CGFloat) -> UInt8 { UInt8(SRGB8.jsRound(Double(min(1, max(0, v))) * 255)) }
        self.init(r: channel(r), g: channel(g), b: channel(b))
    }

    nonisolated var uiColor: UIColor {
        UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}
