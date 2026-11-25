import SwiftUI

/// A design-token color: an 8-bit sRGB value plus opacity. Kept as raw numbers so tests can check
/// contrast; views use `.color`. (Photo-derived pair colors are `SRGB8`, T-010; these are UI chrome.)
nonisolated struct Swatch: Hashable, Sendable {
    let rgb: UInt32          // 0xRRGGBB
    var opacity: Double = 1

    var red: UInt8 { UInt8((rgb >> 16) & 0xFF) }
    var green: UInt8 { UInt8((rgb >> 8) & 0xFF) }
    var blue: UInt8 { UInt8(rgb & 0xFF) }

    var color: Color {
        Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, opacity: opacity)
    }

    func opacity(_ value: Double) -> Swatch { Swatch(rgb: rgb, opacity: value) }
}

/// Colors, spacing, radii and sizes from the web's `index.css` (PM §10), in points (1px ≈ 1pt).
/// iOS changes from the web are marked "iOS:" and recorded in ios.md §8 / §14.
nonisolated enum Tokens {

    // MARK: Surfaces

    enum Surface {
        static let canvas = Swatch(rgb: 0x111214)            // app + deck background, selected-chip text
        static let photoPlaceholder = Swatch(rgb: 0x232427)
        static let toggle = Swatch(rgb: 0x151619)            // mixer toggle (glass on iOS; kept for reference)
        static let toggleHover = Swatch(rgb: 0x292B30)
        static let button = Swatch(rgb: 0x242529)            // buttons, toast
        static let segmented = Swatch(rgb: 0x202125)         // WCAG/APCA switch background
        static let track = Swatch(rgb: 0x34363A)             // contrast meter track
        static let sliderStart = Swatch(rgb: 0x24262B)       // S/L slider track start
        static let credit = Swatch(rgb: 0x0A0A0A, opacity: 0.68)
    }

    // MARK: Text and icons

    enum Text {
        static let primary = Swatch(rgb: 0xF4F4F1)
        static let deck = Swatch(rgb: 0xF3F3EF)
        static let button = Swatch(rgb: 0xD4D5D2)
        static let chip = Swatch(rgb: 0x95979D)              // unselected chip, inactive segment
        /// iOS: web `#777980` is 4.31:1 on the canvas. The deck's glass renders the canvas as about `#15171A`,
        /// so this is 5.63:1 there (5.35:1 even on `#1A1C20`). `subtle` and `tick` use the same value.
        static let muted = Swatch(rgb: 0x8E9097)
        /// iOS: muted under Increase Contrast (8.16:1).
        static let mutedIncreased = Swatch(rgb: 0xA9ABB1)
        static let subtle = Swatch(rgb: 0x8E9097)            // brand subtitle (web #7D7F86)
        static let tick = Swatch(rgb: 0x8E9097)              // AA/AAA tick labels (web #7F8187)
        static let toast = Swatch(rgb: 0xFFFFFF)
        static let creditName = Swatch(rgb: 0xFFFFFF)
        /// iOS: web uses 55% white, which is 3.43:1 when the credit chip sits over a white photo. 75% computes to
        /// 4.85:1, barely AA for 12pt text; iOS uses 85% for margin over bright photos.
        static let creditLabel = Swatch(rgb: 0xFFFFFF, opacity: 0.85)

        /// The muted label color for the current contrast setting.
        static func muted(_ contrast: ColorSchemeContrast) -> Swatch {
            contrast == .increased ? mutedIncreased : muted
        }
    }

    enum Icon {
        static let swap = Swatch(rgb: 0xDADBD8)
    }

    // MARK: Selection, lines, controls

    enum Selected {
        static let chipFill = Swatch(rgb: 0xF4F4EF)
        static let segment = Swatch(rgb: 0xEEEEEE)            // active segment, meter fill
    }

    enum Line {
        /// Borders under Increase Contrast (chip, swap): brighter and 1.5pt.
        static let increased = Swatch(rgb: 0x6A6C73)
        static let increasedWidth: CGFloat = 1.5
        static let chip = Swatch(rgb: 0x303237)
        static let swap = Swatch(rgb: 0x34363B)
        static let tick = Swatch(rgb: 0xA7A8AC)
        static let swatchBorder = Swatch(rgb: 0xFFFFFF, opacity: 0.15)
    }

    enum Thumb {
        static let fill = Swatch(rgb: 0xF5F5F1)
        static let ring = Swatch(rgb: 0x61636A)
    }

    enum Effect {
        static let chipWavePeak = Swatch(rgb: 0x111214, opacity: 0.08)
        static let creditShadow = Swatch(rgb: 0x000000, opacity: 0.18)
        static let focusRing = Swatch(rgb: 0xFFFFFF)
    }

    /// Hue slider track: `#F55 #FF5 #5F5 #5FF #55F #F5F #F55`.
    static let hueGradient: [Swatch] = [0xFF5555, 0xFFFF55, 0x55FF55, 0x55FFFF, 0x5555FF, 0xFF55FF, 0xFF5555]
        .map { Swatch(rgb: $0) }

    // MARK: Spacing (pt)

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32

        static let deckPadding: CGFloat = 16                  // web ≤ 900px
        static let chipGap: CGFloat = 4.48
        static let sliderRowGap: CGFloat = 10.24
        static let creditInset: CGFloat = 16
        static let toastBottom: CGFloat = 19.2
    }

    // MARK: Radii (pt); pills use `Capsule()`

    enum Radius {
        static let button: CGFloat = 4.8
        static let credit: CGFloat = 4.48
        static let toast: CGFloat = 4.8
        static let toggle: CGFloat = 0                       // web: square
    }

    // MARK: Sizes (pt)

    enum Size {
        static let minHitTarget: CGFloat = 44
        static let mixerToggle: CGFloat = 48
        static let mixerIcon: CGFloat = 20
        static let mixerIconStroke: CGFloat = 1.6
        static let buttonIcon: CGFloat = 14.4
        static let buttonIconStroke: CGFloat = 1.7
        static let swatch: CGFloat = 23.2
        static let swapButton: CGFloat = 32
        static let sliderTrack: CGFloat = 4
        static let sliderThumb: CGFloat = 12
        static let contrastTrack: CGFloat = 5.12
        static let tickWidth: CGFloat = 1
        static let tickHeight: CGFloat = 14.4

        /// Deck height when open: `min(60% of the screen, 544pt)` (PM §10, ≤ 900px).
        static let deckMaxHeight: CGFloat = 544
        static let deckHeightFraction: CGFloat = 0.6
    }
}
