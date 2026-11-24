# Color science and image sampling in Swift (APCA, WCAG 2.x, sRGB, 32×32 sampling)

Last checked: 2026-11-24

Scope: native iOS (SwiftUI) port of "Color Shift". The web version draws each photo into a 32×32 canvas, reads the pixels, converts to HSL, picks and tunes a foreground/background pair, and reports WCAG 2.x contrast ratio and APCA Lc. This file covers the color math and the image-sampling pipeline in Swift.

Verification legend: **[verified]** means I ran it locally (Swift 6.4.2 / Python 3 on macOS, in the scratchpad) or quoted it from the primary source. **[unverified]** means it comes from memory, secondary sources or inference and needs a check before you rely on it.

---

## TL;DR

- **APCA 0.0.98G-4g is easy to port.** It is about 25 lines of pure math. The constants below are copied verbatim from `Myndex/apca-w3/src/apca-w3.js` [1]. A Swift port and a Python port both **reproduce all six project test vectors to 3 decimal places** [verified]. WCAG ratios for the same pairs are 3.545, 9.040 and 21.000 [verified].
- **Licensing is the big risk, not the math.** The apca-w3 license is a custom "W3 License for Compliant Code Only". It limits use to "web-delivered and web-based content only" and says "commercial use is prohibited without a written and signed commercial license agreement" [2]. Porting to another language is allowed, but **a native iOS app looks to be outside the licensed scope**. Get legal review or written permission from Myndex before shipping. Also don't brand the feature "APCA" unless it is compliant and kept up to date [2].
- **No canonical Swift APCA package exists.** None turned up in search [3]. Port it yourself (snippet below) and pin it with the test vectors.
- **WCAG 2.x:** use the 0.04045 threshold. WCAG 2.2 notes the old value was 0.03928 and that the change has "no practical effect" [4]. For 8-bit hex input the two thresholds give **identical** results, because no `n/255` falls between 0.03928 and 0.04045 (10/255 = 0.03922, 11/255 = 0.04314) [verified].
- **Do all hex, contrast and HSL math on 8-bit sRGB integers (or Doubles derived from them), never on SwiftUI `Color`.** `Color` is extended-range [5][6]. `Color.Resolved` stores `Float` values in extended linear sRGB [6], so out-of-gamut (P3) values can go below 0 or above 1.
- **Sampling:** use ImageIO `CGImageSourceCreateThumbnailAtIndex` for a cheap decode with EXIF orientation applied [8][9]. Then draw into a 32×32 `CGContext` with an **explicit sRGB color space** and `premultipliedLast` [10], un-premultiply, and run it off the main actor (`@concurrent` in Swift 6.2+) [15]. I tested that CG converts a Display-P3-tagged source into the sRGB context and clips out-of-gamut values [verified].
- **Expect small mismatches with the web.** The canvas spec converts drawn images to the canvas color space (default `"srgb"`) [11] and does **not** mandate an interpolation algorithm [11]. Browsers and CoreGraphics therefore downscale to 32×32 differently. Treat per-pixel equality with the web as unattainable. Test with tolerances.
- **HSL:** float HSL round-trips exactly. Integer-rounded HSL (what CSS strings and many UIs keep) changed 89% of a sampled RGB grid [verified]. Store colors as 8-bit sRGB (or Double sRGB) and treat HSL as a derived view. OKLCH/OKLab [14] is a better space for "tuning lightness", but it is optional.

---

## 1. APCA 0.0.98G-4g

### 1.1 Canonical source and version naming

- Canonical code: `Myndex/apca-w3`, file `src/apca-w3.js`. Header: "SAPC APCA … Beta 0.1.9 W3 • contrast function only … Revision date: July 3, 2022 … LICENSE: W3 LICENSE" [1]. The constants block is labelled "G-4g constants for use with 2.4 exponent", and `sRGBtoY` says "APCA 0.0.98G - 4g - W3 Compatible Constants" [1]. **The package version (0.1.x) and the algorithm version (0.0.98G-4g) are different things.**
- The SAPC-APCA README calls `apca-w3` "the only code that should be used for any development purpose" and points to the npm package `apca-w3` [3a]. The README writes the version inconsistently ("0.9.98G-4g", "0.0.98G-4g") [3a]. The constants are the same, so use **0.0.98G-4g** in docs.
- The license says "the current base algorithm is 0.0.98G-4g" and mentions an output clamp near ±Lc 10 [2]. That clamp is the `loClip = 0.1` (Lc 10) in the code.

### 1.2 Exact constants (verbatim from [1])

| Constant | Value | Role |
|---|---|---|
| `mainTRC` | 2.4 | simple power-curve linearization ("emulating actual monitor perception") |
| `sRco` | 0.2126729 | R luminance coefficient |
| `sGco` | 0.7151522 | G luminance coefficient |
| `sBco` | 0.0721750 | B luminance coefficient |
| `normBG` | 0.56 | BoW (dark text on light bg) bg exponent |
| `normTXT` | 0.57 | BoW text exponent |
| `revTXT` | 0.62 | WoB (light text on dark bg) text exponent |
| `revBG` | 0.65 | WoB bg exponent |
| `blkThrs` | 0.022 | black soft-clamp threshold |
| `blkClmp` | 1.414 | black soft-clamp exponent |
| `scaleBoW` | 1.14 | BoW scale |
| `scaleWoB` | 1.14 | WoB scale |
| `loBoWoffset` | 0.027 | BoW low offset |
| `loWoBoffset` | 0.027 | WoB low offset |
| `deltaYmin` | 0.0005 | return 0 if \|ΔY\| below this |
| `loClip` | 0.1 | low clip (Lc 10) |

The same object also defines reverse-APCA "magic numbers" (`mFactor 1.94685544331710`, `mOffsetIn 0.03873938165714010`, `mExpAdj 0.2833433964208690`, `mOffsetOut 0.3128657958707580`). They are only needed for `reverseAPCA` (solving for a color that hits a target Lc) [1]. If Color Shift ever "tunes until Lc ≥ X", a numeric search over lightness with the forward function is simpler and avoids porting more licensed code.

Note: `sRGBtoY` carries a comment with "Future" coefficients (0.2126478133913640, 0.7151791475336150, 0.0721730390750208) [1]. **They are not used.** Don't swap them in.

### 1.3 Algorithm steps (from [1])

1. **Linearize (APCA's own, not the sRGB piecewise curve):** `Y = sRco·(R/255)^2.4 + sGco·(G/255)^2.4 + sBco·(B/255)^2.4`. No 0.04045 linear toe.
2. **Input check:** return 0 if either Y is NaN, below 0.0, or above 1.1.
3. **Black soft clamp,** on each Y separately: `Y = Y > 0.022 ? Y : Y + (0.022 − Y)^1.414`.
4. **Early exit:** if `|Ybg − Ytxt| < 0.0005`, return 0.
5. **Polarity:**
   - If `Ybg > Ytxt` (BoW, normal): `SAPC = (Ybg^0.56 − Ytxt^0.57) · 1.14`. Then `out = SAPC < 0.1 ? 0 : SAPC − 0.027`.
   - Otherwise (WoB, reverse): `SAPC = (Ybg^0.65 − Ytxt^0.62) · 1.14`. Then `out = SAPC > −0.1 ? 0 : SAPC + 0.027`.
6. **Return** `Lc = out × 100`, a signed float. Positive means dark text on light; negative means light text on dark. **Argument order matters: text first, then background.** The JS `places` parameter only controls string formatting. Keep the raw Double in Swift and format it in the UI.

### 1.4 Reference Swift implementation [verified, compiled and run with Swift 6.4.2]

```swift
import Foundation

/// 8-bit sRGB color — the canonical stored form for the app.
struct SRGB8: Hashable, Sendable, Codable {
    var r: UInt8, g: UInt8, b: UInt8

    init(r: UInt8, g: UInt8, b: UInt8) { self.r = r; self.g = g; self.b = b }

    /// Accepts "#RRGGBB", "RRGGBB", "#RGB".
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        r = UInt8((v >> 16) & 0xFF); g = UInt8((v >> 8) & 0xFF); b = UInt8(v & 0xFF)
    }

    var hex: String { String(format: "#%02X%02X%02X", r, g, b) }
}

/// APCA 0.0.98G-4g, ported from Myndex/apca-w3 (src/apca-w3.js, Beta 0.1.9 W3).
/// See licensing notes before shipping.
enum APCA {
    static let mainTRC = 2.4
    static let sRco = 0.2126729, sGco = 0.7151522, sBco = 0.0721750
    static let normBG = 0.56, normTXT = 0.57, revTXT = 0.62, revBG = 0.65
    static let blkThrs = 0.022, blkClmp = 1.414
    static let scaleBoW = 1.14, scaleWoB = 1.14
    static let loBoWoffset = 0.027, loWoBoffset = 0.027
    static let deltaYmin = 0.0005, loClip = 0.1

    /// APCA screen luminance (simple 2.4 exponent — NOT the WCAG piecewise curve).
    static func y(_ c: SRGB8) -> Double {
        func e(_ v: UInt8) -> Double { pow(Double(v) / 255.0, mainTRC) }
        return sRco * e(c.r) + sGco * e(c.g) + sBco * e(c.b)
    }

    /// Signed Lc. Polarity matters: text first, background second.
    static func contrast(textY: Double, backgroundY: Double) -> Double {
        guard textY.isFinite, backgroundY.isFinite,
              min(textY, backgroundY) >= 0, max(textY, backgroundY) <= 1.1 else { return 0 }
        func softClamp(_ y: Double) -> Double { y > blkThrs ? y : y + pow(blkThrs - y, blkClmp) }
        let t = softClamp(textY), b = softClamp(backgroundY)
        guard abs(b - t) >= deltaYmin else { return 0 }
        let out: Double
        if b > t {                                   // BoW
            let sapc = (pow(b, normBG) - pow(t, normTXT)) * scaleBoW
            out = sapc < loClip ? 0 : sapc - loBoWoffset
        } else {                                     // WoB
            let sapc = (pow(b, revBG) - pow(t, revTXT)) * scaleWoB
            out = sapc > -loClip ? 0 : sapc + loWoBoffset
        }
        return out * 100
    }

    static func lc(text: SRGB8, background: SRGB8) -> Double {
        contrast(textY: y(text), backgroundY: y(background))
    }
}
```

### 1.5 Check against the project test vectors [verified]

The Swift code above and an independent Python port (`apca.py` / `apca.swift` in the scratchpad) both print:

| Text | Background | Expected Lc | Swift/Python Lc | Match (±0.0005) | WCAG 2.x ratio |
|---|---|---|---|---|---|
| #888888 | #FFFFFF | 63.056 | 63.056 | yes | 3.545 |
| #FFFFFF | #888888 | −68.541 | −68.541 | yes | 3.545 |
| #000000 | #AAAAAA | 58.146 | 58.146 | yes | 9.040 |
| #AAAAAA | #000000 | −56.241 | −56.241 | yes | 9.040 |
| #000000 | #FFFFFF | 106.041 | 106.041 | yes | 21.000 |
| #FFFFFF | #000000 | −107.885 | −107.885 | yes | 21.000 |

Note the asymmetry (63.1 vs −68.5 for the same pair swapped). That is the expected APCA polarity behaviour and it confirms the port is not symmetric by accident.

### 1.6 Licensing and usage terms (apca-w3) [2]

Quoted from `apca-w3/LICENSE.md`. This is not legal advice.

- Title: "W3 License for Compliant Code Only".
- Scope: "for use with WCAG accessibility guidelines for web-delivered and web-based content only".
- Excluded: "uses which are not specific to web-based content presented on self-illuminated displays or devices", plus medical, clinical, safety, aerospace, transportation and military uses.
- Commercial: "Commercial use is prohibited without a written and signed commercial license agreement" (the W3 web-content agreement is the exception).
- Modification: essential elements and approved constants must not change, "except as required to port to a given language". **A faithful Swift port is allowed under this clause.**
- Naming: "APCA" / "SAPC" may only describe code that is "correctly implemented, maintained, and up to date". Integrators are expected to track the latest version. Logos and trademarks need consent.
- Commercial or paywalled integrations must give Myndex free access for verification on request.
- Attribution: keep notices and add a copyright statement that references the source.

**Implication for Color Shift iOS:** a native App Store app is not "web-delivered content". If the app is paid or commercial, the license plainly requires a signed agreement. Options: (a) contact Myndex (the license asks for contact via the GitHub Issues/Discussions tab [1]); (b) label the metric something neutral and avoid the APCA trademark (this does **not** fix the copyright/licence scope by itself); (c) ship WCAG 2.x only on iOS. Flag this for product and legal review. **[Interpretation unverified, needs legal review.]**

### 1.7 Swift package availability

A search found no Swift APCA package from Myndex and no widely used third-party one [3]. `markbattistella/ContrastKit` and `chrs1885/WCAG-Colors` came up as Swift contrast libraries, but I did **not** confirm that either implements APCA 0.0.98G-4g [unverified]. Recommendation: own the roughly 40-line port above, pin it with the vectors, and add the license and attribution header.

---

## 2. WCAG 2.x relative luminance and contrast ratio

From the WCAG 2.2 glossary [4]:

- Relative luminance: `L = 0.2126·R + 0.7152·G + 0.0722·B`, where each channel is `c ≤ 0.04045 ? c/12.92 : ((c+0.055)/1.055)^2.4`.
- Note 2: "Before May 2021 the value of 0.04045 in the definition was different (0.03928)". The change "has no practical effect on the calculations in the context of these guidelines."
- Contrast ratio: `(L1 + 0.05) / (L2 + 0.05)`, where L1 is the lighter value. The range is 1–21.

**Threshold discrepancy, settled for this app [verified]:** 8-bit channels only take values `n/255`. 10/255 = 0.039216 is below both thresholds, and 11/255 = 0.043137 is above both. So for any hex color, 0.03928 and 0.04045 give bit-identical luminance. They only diverge for non-8-bit inputs, such as continuous HSL sliders before quantization. Use 0.04045 (current spec and the IEC 61966-2-1 sRGB definition [7]).

Note that the WCAG luminance coefficients (0.2126/0.7152/0.0722) differ slightly from APCA's (0.2126729/0.7151522/0.0721750), and the two transfer curves differ too. Don't share a `luminance()` function between them.

```swift
enum WCAG {
    @inline(__always)
    static func linearize(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    static func relativeLuminance(_ c: SRGB8) -> Double {
        0.2126 * linearize(Double(c.r) / 255)
      + 0.7152 * linearize(Double(c.g) / 255)
      + 0.0722 * linearize(Double(c.b) / 255)
    }
    /// 1...21, order-independent.
    static func contrastRatio(_ a: SRGB8, _ b: SRGB8) -> Double {
        let la = relativeLuminance(a), lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
```

Display and threshold note: WCAG says not to round up when comparing against 4.5:1 or 3:1. Compare the raw Double (`ratio >= 4.5`) and only round for display. If the web version rounds before comparing, decide which behaviour is canonical. **[Check against the web code.]**

---

## 3. Color spaces on iOS

### 3.1 What the APIs actually give you

| API | Space and range | Notes |
|---|---|---|
| `Color(.sRGB, red:green:blue:opacity:)` (iOS 13+) | sRGB-encoded inputs, **extended** range | "SwiftUI colors use an extended sRGB color space, so you can use component values outside that range" [5]. The default `colorSpace` is `.sRGB`. Other options: `.sRGBLinear`, `.displayP3`. |
| `Color.resolve(in: EnvironmentValues) -> Color.Resolved` (iOS 17+) | — | "Evaluates this color to a resolved color given the current context" [6b]. |
| `Color.Resolved` (iOS 17+) | `Float` values, "stored in the Linear sRGB color space, using extended range" | `red/green/blue` are gamma-encoded sRGB; `linearRed/linearGreen/linearBlue` are linear; plus `opacity` and `cgColor` [6]. |
| `UIColor.getRed(_:green:blue:alpha:)` | extended sRGB (iOS 10+) | "an extended range sRGB color space specifies the red component and can have any value. Values between 0.0 and 1.0 are inside the sRGB color gamut" [12]. Returns `false` if the color isn't in a compatible space. |
| `CGColorSpace.sRGB` | IEC 61966-2-1 sRGB [7] | Siblings: `.extendedSRGB`, `.displayP3`, `.linearSRGB`, `.extendedLinearSRGB`. |

### 3.2 Rules for Color Shift

1. **Source of truth: `SRGB8`** (or a `Double` sRGB triple in 0…1 if you need sub-8-bit precision while tuning). Hex, WCAG, APCA and HSL all operate on this type.
2. **Go to SwiftUI one way only:** `Color(.sRGB, red: Double(c.r)/255, green: Double(c.g)/255, blue: Double(c.b)/255)`. Never read numbers back out of a `Color` to do math.
3. If you must read a `Color` (for example a system or asset color), resolve it and quantize in **sRGB encoded** space, clamping to 0…1:

```swift
import SwiftUI

@available(iOS 17, *)
extension SRGB8 {
    init(_ color: Color, in env: EnvironmentValues) {
        let r = color.resolve(in: env)
        func q(_ v: Float) -> UInt8 { UInt8((min(max(Double(v), 0), 1) * 255).rounded()) }
        self.init(r: q(r.red), g: q(r.green), b: q(r.blue))   // clamps P3 out-of-gamut
    }
}

extension Color {
    init(_ c: SRGB8) {
        self.init(.sRGB, red: Double(c.r) / 255, green: Double(c.g) / 255, blue: Double(c.b) / 255)
    }
}
```

4. **UIKit/CG fallback** (iOS < 17): `UIColor(color).cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .relativeColorimetric, options: nil)?.components`. Then clamp and quantize as above. [`CGColor.converted(to:intent:options:)` exists since iOS 9; not re-fetched, unverified detail.]
5. **Float precision:** `Color.Resolved` uses `Float` (24-bit mantissa). Quantizing a `Float` to 8 bits is safe, but don't chain math through `Float` and compare to the web's Doubles. Do the math in `Double` from `UInt8` (as above). The test vectors match to 1e-3 with Doubles [verified].
6. **Gamut:** iPhone displays are Display P3. An sRGB `Color` renders correctly (color-managed), so the on-screen swatch matches the web on a color-managed browser. Sampled colors that were outside sRGB in a P3 photo are clipped to sRGB at sampling time (§4), which is the same thing an `"srgb"` canvas does [11].

### 3.3 Hex parsing and formatting

`SRGB8.init?(hex:)` and `.hex` are in §1.4 [verified for the six vectors]. Normalize output to upper-case `#RRGGBB` (or match the web's casing). Decide whether 8-digit `#RRGGBBAA` input should be rejected or have its alpha dropped. Recommendation: reject it, since the app has no alpha colors.

---

## 4. Downsampling to 32×32 and reading pixels

### 4.1 Pipeline

1. **Decode small with ImageIO:** use `CGImageSourceCreateWithData`/`WithURL` with `kCGImageSourceShouldCache: false`, then `CGImageSourceCreateThumbnailAtIndex` with:
   - `kCGImageSourceCreateThumbnailFromImageAlways: true`. Without `kCGImageSourceThumbnailMaxPixelSize`, "the image source creates the thumbnail using the image's full size, which in most cases is not desirable" [8].
   - `kCGImageSourceThumbnailMaxPixelSize`: 128–256. A 2-step downscale (decoder → ~256 → 32) is closer to a browser's high-quality result than a direct 4000 → 32 draw [unverified heuristic].
   - `kCGImageSourceCreateThumbnailWithTransform: true` applies EXIF orientation [9].
   - `kCGImageSourceShouldCacheImmediately: true` decodes now, on your background task [9].

   This is the WWDC18 session 219 "Image and Graphics Best Practices" pattern [9].
2. **Draw into a 32×32 bitmap with an explicit sRGB color space.** On iOS, the supported 8-bpc RGB `CGBitmapContext` formats are `NoneSkipFirst/Last` and `PremultipliedFirst/Last` (no straight alpha) [10]. Use `premultipliedLast | byteOrder32Big` to get RGBA bytes like canvas `getImageData`. CG color-matches the source (embedded ICC, e.g. Display P3) into the context's sRGB space [verified: a P3 `#336699` came out as sRGB (27,103,157); P3 pure red was clipped to (255,0,0)].
3. **Un-premultiply.** Photos are opaque (alpha 255), so this is a no-op except for PNGs with transparency. Canvas `getImageData` also returns non-premultiplied values, and the spec warns that premultiplied round-trips are lossy [11].
4. Convert to `SRGB8` and hand it to the existing HSL/pick logic.

```swift
import CoreGraphics
import ImageIO
import Foundation

struct RGBA8: Sendable, Equatable { var r, g, b, a: UInt8 }

enum PixelSampler {
    static func thumbnail(from data: Data, maxPixelSize: Int = 256) -> CGImage? {
        let srcOpts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, srcOpts) else { return nil }
        let opts = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts)
    }

    /// Row-major, top-left origin (CG bitmap memory is top row first), RGBA, un-premultiplied, sRGB.
    static func pixels(of image: CGImage, side: Int = 32) -> [RGBA8]? {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bytesPerRow = side * 4
        var buf = [UInt8](repeating: 0, count: side * bytesPerRow)
        let ok: Bool = buf.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: side, height: side,
                                      bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: srgb,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                                                | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            ctx.interpolationQuality = .medium        // tune vs. web; see 4.4
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side)) // stretches like drawImage(img,0,0,32,32)
            return true
        }
        guard ok else { return nil }
        return stride(from: 0, to: buf.count, by: 4).map { i in
            let a = buf[i + 3]
            func un(_ c: UInt8) -> UInt8 {
                a == 0 ? 0 : (a == 255 ? c : UInt8(min(255, (Int(c) * 255 + Int(a) / 2) / Int(a))))
            }
            return RGBA8(r: un(buf[i]), g: un(buf[i + 1]), b: un(buf[i + 2]), a: a)
        }
    }
}
```

[verified: compiles and runs on macOS 26 / Swift 6.4.2; a solid sRGB `#336699` source samples back exactly as (51,102,153,255).]

Aspect ratio: the web snippet presumably does `drawImage(img, 0, 0, 32, 32)`, which stretches. The code above does the same. If the web crops or letterboxes, mirror it exactly. **[Check the web code.]**

### 4.2 Off the main actor (Swift concurrency)

Decoding and drawing are synchronous and CPU-bound, so keep them off `@MainActor`. In Swift 6.2+, with `NonisolatedNonsendingByDefault` (on by default in new Xcode projects' "approachable concurrency" settings [unverified about Xcode defaults]), a plain `nonisolated async` function **runs on the caller's actor**. Mark the work `@concurrent` so it always leaves the actor [15].

```swift
struct PaletteSample: Sendable { let pixels: [RGBA8] }

enum Sampler {
    @concurrent
    static func sample(_ data: Data) async throws -> PaletteSample {
        try Task.checkCancellation()
        guard let thumb = PixelSampler.thumbnail(from: data),
              let px = PixelSampler.pixels(of: thumb) else { throw CocoaError(.fileReadCorruptFile) }
        return PaletteSample(pixels: px)
    }
}

// In a @MainActor view model:
// let sample = try await Sampler.sample(data)   // hops off main, result is Sendable
```

On older toolchains, or without the upcoming feature, a `nonisolated static func … async` already runs on the global executor. `Task.detached(priority: .userInitiated)` also works but loses structured cancellation.

### 4.3 Core Image alternatives

- `CIFilter.areaAverage()` (iOS 14+ typed API) returns "a 1 x 1 pixel image that contains the average color for the region of interest", processing each channel independently [13a]. It is good for one dominant average. **But** a `CIContext` works by default in "extended sRGB color space with linear gamma" [13c], so the average is computed in **linear light**. A browser canvas averages gamma-encoded bytes [unverified for each browser's resampler, but `getImageData` returns encoded sRGB]. Results come out lighter and won't match the web. If you want parity, create the context with `.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!` or `NSNull()` [13c].
- `CIFilter.kMeans()` (iOS 14+) has `count` (default 8, max 128), `passes` (default 5, max 20) and `perceptual`. It outputs a `count×1` image whose alpha is the cluster weight [13b]. This is attractive for "dominant colors", but the web doesn't do it, so it changes product behaviour. Treat it as a future enhancement.
- To read a CI output, use `CIContext.render(_:toBitmap:rowBytes:bounds:format:.RGBA8,colorSpace: sRGB)`. Reuse a single `CIContext`, because creating one is expensive [unverified, general Apple guidance].

For parity with the web (32×32 grid → HSL → pick), **CGContext is the right default**. CI only helps if the algorithm changes.

### 4.4 Matching the browser canvas: known mismatch sources

| Source | Web | iOS | Risk |
|---|---|---|---|
| Color management | The 2D context converts drawn images to the context's color space (default `"srgb"`); `getImageData` converts with relative-colorimetric intent [11] | CG converts embedded ICC to the sRGB context [verified] | Low for sRGB/untagged JPEGs. Small for P3 sources (different CMMs, rounding of ±1). |
| Untagged images | Browsers assume sRGB [unverified, standard behaviour] | ImageIO assumes sRGB for untagged RGB JPEGs [unverified] | Low |
| Resampling filter | Spec: "does not mandate that specific interpolation algorithms be used"; `imageSmoothingQuality` default `"low"` [11]. Chrome, Safari and Firefox differ. | CG `interpolationQuality`, plus the ImageIO thumbnail filter | **Medium–High: per-pixel values will differ.** Picks based on rank or threshold may flip on borderline photos. |
| Gamma of averaging | Encoded-space blending (typical) [unverified] | CG draws in encoded space for 8-bit sRGB contexts [unverified]; CI defaults to linear [13c] | Medium if you use CI |
| EXIF orientation | CSS `image-orientation: from-image` is the default for `<img>`/canvas draws in modern browsers [unverified] | `CreateThumbnailWithTransform: true` [9] | Low if both apply it. Position-dependent logic breaks if one doesn't. |
| Unsplash JPEGs | Unsplash serves through imgix CDN params (`w=`, `fm=`, `q=`). Whether ICC profiles survive the CDN depends on params; many are sRGB or untagged [unverified] | If the app requests a different URL size, the CDN re-encodes a different JPEG | **Medium: request the same URL (same `w`/`q`/`fm`) as the web for parity tests.** |
| JPEG decoder | libjpeg-turbo or the browser's own decoder (Safari uses ImageIO [unverified]) | ImageIO | Low (±1 from IDCT/upsampling differences) |

**Recommendation:** define parity as "same picked colors within ΔE / ±N per channel on a golden set". Don't aim for byte equality. Build a small golden fixture: export the web's 32×32 `getImageData` arrays (JSON) for about 10 Unsplash photos, run the iOS sampler on the same image bytes, and assert mean absolute channel error ≤ ~3 and identical or nearby final picks. Pick the `interpolationQuality` and `maxPixelSize` that minimize the error empirically.

### 4.5 Performance

ImageIO thumbnailing avoids decoding the full bitmap into memory. WWDC18 219 showed memory going from 31.5 MB to 18.4 MB in its example [9]. A 32×32 draw (4 KB buffer) plus pixel loop costs microseconds. Decode dominates: likely a few ms to tens of ms for a 12 MP HEIC/JPEG on recent devices [unverified, measure with Instruments]. Cache results per image ID.

---

## 5. HSL round-trip precision and perceptual spaces

**Measured [verified, scratchpad `apca.swift`]:** on a 52³ = 140,608 RGB grid (step 5):
- RGB8 → HSL (Double) → RGB8 with rounding: **140,608 / 140,608 exact**.
- RGB8 → HSL **rounded to integers** (h°, s%, l%) → RGB8: **125,180 / 140,608 changed (89%)**.

So the web's "HSL drift" most likely comes from storing or serializing rounded HSL (for example `hsl(210 50% 40%)` strings) and converting back, not from the formulas.

Recommendations:
- Store colors as `SRGB8` (exact, hex-compatible) or a `Double` sRGB triple during interactive tuning. Compute HSL on demand.
- When tuning (for example nudging lightness until contrast passes), work in Double HSL from the original, quantize to `SRGB8` **once** at the end, then compute WCAG/APCA on the quantized value. This makes the reported contrast match the hex that is shown.
- Port the web's exact HSL functions, including its hue convention for achromatic colors (h = 0) and its rounding, if you need the same picks. Otherwise picks on grays and edge cases differ.

**OKLab/OKLCH (mention only):** OKLab is designed so that "lightness, chroma, and hue should be predicted well and perceived as orthogonal", which is better than HSL, where L=50% yellow and blue differ hugely in perceived lightness [14]. The conversion is a 3×3 matrix, a cube root, and another 3×3 matrix on **linear** sRGB [14] (public domain / MIT). A future "tune lightness" step in OKLCH would converge faster on a target contrast with fewer hue shifts. That would change outputs compared with the web, though, so keep HSL for v1 parity and treat OKLCH as an opt-in improvement. Out-of-gamut OKLCH results need gamut mapping back to sRGB (chroma reduction). Don't just clamp.

---

## 6. Test strategy (Swift Testing)

Use parameterized `@Test(arguments:)`. Pass a single collection of tuples, or use `zip` to avoid a Cartesian product [16].

```swift
import Testing
@testable import ColorShift

struct LcVector: Sendable, CustomTestStringConvertible {
    let text: String, background: String, lc: Double
    var testDescription: String { "\(text) on \(background) → \(lc)" }
}

let apcaVectors: [LcVector] = [
    .init(text: "#888888", background: "#FFFFFF", lc:   63.056),
    .init(text: "#FFFFFF", background: "#888888", lc:  -68.541),
    .init(text: "#000000", background: "#AAAAAA", lc:   58.146),
    .init(text: "#AAAAAA", background: "#000000", lc:  -56.241),
    .init(text: "#000000", background: "#FFFFFF", lc:  106.041),
    .init(text: "#FFFFFF", background: "#000000", lc: -107.885),
]

@Suite("Contrast")
struct ContrastTests {
    @Test("APCA 0.0.98G-4g vectors", arguments: apcaVectors)
    func apca(_ v: LcVector) throws {
        let t = try #require(SRGB8(hex: v.text))
        let b = try #require(SRGB8(hex: v.background))
        #expect(abs(APCA.lc(text: t, background: b) - v.lc) < 0.0005)
    }

    @Test("WCAG ratio", arguments: [
        ("#888888", "#FFFFFF", 3.545), ("#000000", "#AAAAAA", 9.040), ("#000000", "#FFFFFF", 21.0),
    ])
    func wcag(_ a: String, _ b: String, _ expected: Double) throws {
        let r = WCAG.contrastRatio(try #require(SRGB8(hex: a)), try #require(SRGB8(hex: b)))
        #expect(abs(r - expected) < 0.0005)
        #expect(r == WCAG.contrastRatio(SRGB8(hex: b)!, SRGB8(hex: a)!))   // symmetric
    }

    @Test("Old/new WCAG thresholds agree for every 8-bit value", arguments: 0...255)
    func threshold(_ n: Int) {
        let c = Double(n) / 255
        let old = c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        #expect(old == WCAG.linearize(c))
    }

    @Test("Hex round-trip", arguments: ["#000000", "#FFFFFF", "#888888", "#1A2B3C", "#abc"])
    func hex(_ s: String) throws {
        let c = try #require(SRGB8(hex: s))
        #expect(SRGB8(hex: c.hex) == c)
    }

    @Test func apcaEdgeCases() {
        #expect(APCA.lc(text: SRGB8(r: 128, g: 128, b: 128), background: SRGB8(r: 128, g: 128, b: 128)) == 0)
        #expect(APCA.contrast(textY: .nan, backgroundY: 1) == 0)
        #expect(APCA.contrast(textY: -0.1, backgroundY: 1) == 0)
    }
}
```

Additional tests to add:
- **HSL round-trip property:** for every RGB on a coarse grid, `rgb → hsl(Double) → rgb == rgb`. Also a test that documents the integer-rounding drift, so nobody reintroduces it.
- **Sampler unit tests:** generate solid-color `CGImage`s in sRGB and Display P3 (as in §4.1), and a 2-color split image. Assert the sampled colors (exact for sRGB solid, ±1 for P3 conversion).
- **Web parity golden tests:** check in JSON fixtures of the web's 32×32 `getImageData` output and final picked hex pair for about 10 bundled test images (bundle the exact image bytes, don't fetch them). Assert mean channel error ≤ tolerance and that the picked pair has the same or near-same hex. The final pick may legitimately differ on borderline photos, so record known exceptions.
- **Mutation guard for APCA constants:** a test that asserts each constant's value, because the license forbids changing them [2].

---

## Open questions / uncertain

1. **APCA license fit for a native iOS app (highest priority).** The license text limits use to web content and requires a signed agreement for commercial use [2]. Needs legal or Myndex confirmation. It may force shipping WCAG-only on iOS, or a different label.
2. Whether the web app rounds contrast before threshold comparisons, and how it formats Lc (`toFixed`? abs + polarity?). Mirror it exactly. [Check the web source.]
3. The web's exact `drawImage` call (stretch, crop or cover), `imageSmoothingQuality`, and the browser used for reference values. These determine the achievable parity.
4. Which interpolation/thumbnail size best matches Chrome or Safari. Settle it empirically with golden fixtures.
5. Whether Unsplash/imgix URLs used by the web carry ICC profiles, and whether the iOS app will fetch the same URL variant. [unverified]
6. Whether CGContext resampling for an 8-bit sRGB context blends in encoded or linear space. [unverified; measure with a black/white checkerboard: encoded blending gives ~128, linear gives ~188.]
7. Swift 6.2 `@concurrent` and Xcode default build settings (`NonisolatedNonsendingByDefault`). Confirm in the project's build settings [15].
8. No Swift APCA library was verified to exist. ContrastKit/WCAG-Colors APCA support is unchecked [3].
9. APCA versioning: track `apca-w3` releases. The license expects integrators to stay current [2]. Note the README's inconsistent "0.9.98G-4g" vs "0.0.98G-4g" wording [3a].

---

## Sources

1. [1] Myndex, `apca-w3` source, `src/apca-w3.js` (constants, `APCAcontrast`, `sRGBtoY`). https://raw.githubusercontent.com/Myndex/apca-w3/master/src/apca-w3.js
2. [2] Myndex, `apca-w3` LICENSE.md ("W3 License for Compliant Code Only"). https://raw.githubusercontent.com/Myndex/apca-w3/master/LICENSE.md
3. [3] Web search, "APCA Swift package" (results: ContrastKit https://github.com/markbattistella/ContrastKit, WCAG-Colors https://github.com/chrs1885/WCAG-Colors; no Swift APCA port found).
4. [3a] Myndex, SAPC-APCA README. https://github.com/Myndex/SAPC-APCA
5. [4] W3C, WCAG 2.2, glossary "relative luminance" / "contrast ratio". https://www.w3.org/TR/WCAG22/
6. [5] Apple, SwiftUI `Color.init(_:red:green:blue:opacity:)`. https://developer.apple.com/documentation/swiftui/color/init(_:red:green:blue:opacity:)
7. [6] Apple, SwiftUI `Color.Resolved`. https://developer.apple.com/documentation/swiftui/color/resolved
8. [6b] Apple, SwiftUI `Color.resolve(in:)`. https://developer.apple.com/documentation/swiftui/color/resolve(in:)
9. [7] Apple, `CGColorSpace.sRGB`. https://developer.apple.com/documentation/coregraphics/cgcolorspace/srgb
10. [8] Apple, ImageIO `kCGImageSourceCreateThumbnailFromImageAlways`. https://developer.apple.com/documentation/imageio/kcgimagesourcecreatethumbnailfromimagealways
11. [9] WWDC18 Session 219 "Image and Graphics Best Practices" (notes). https://wwdcnotes.com/documentation/wwdc18-219-image-and-graphics-best-practices/ (session page: https://developer.apple.com/videos/play/wwdc2018/219/)
12. [10] Apple, Quartz 2D Programming Guide, Graphics Contexts: Supported Pixel Formats. https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_context/dq_context.html
13. [11] WHATWG HTML Standard, canvas (`colorSpace` default `"srgb"`, drawing model color conversion, `getImageData`, premultiplied-alpha note, `imageSmoothingQuality`). https://html.spec.whatwg.org/multipage/canvas.html
14. [12] Apple, `UIColor.getRed(_:green:blue:alpha:)`. https://developer.apple.com/documentation/uikit/uicolor/getred(_:green:blue:alpha:)
15. [13a] Apple, `CIFilter.areaAverage()`. https://developer.apple.com/documentation/coreimage/cifilter-swift.class/areaaverage()
16. [13b] Apple, `CIFilter.kMeans()`. https://developer.apple.com/documentation/coreimage/cifilter-swift.class/kmeans()
17. [13c] Apple, `CIContextOption.workingColorSpace`. https://developer.apple.com/documentation/coreimage/cicontextoption/workingcolorspace
18. [14] Björn Ottosson, "A perceptual color space for image processing" (OKLab). https://bottosson.github.io/posts/oklab/
19. [15] Swift Evolution SE-0461, "Run nonisolated async functions on the caller's actor by default" (`@concurrent`, `nonisolated(nonsending)`, `NonisolatedNonsendingByDefault`). https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md
20. [16] Apple, Swift Testing, "Implementing parameterized tests". https://developer.apple.com/documentation/testing/parameterizedtesting
