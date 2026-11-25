import CoreGraphics
import Foundation
import ImageIO

/// Derives a photo's color pair, porting the web's `deriveFromPhoto` (PM §8.9; ios.md §7 Sampling).
/// The steps are split so tests can drive each one: pixels → samples → pair.
nonisolated enum PhotoSampler {

    /// A derived pair, plus whether tuning reached 4.5:1 (the web misses silently; ios.md §14).
    struct Result: Hashable, Sendable {
        var pair: ColorPair
        var reachedTarget: Bool
    }

    /// The web draws the whole image into a 32×32 canvas.
    static let side = 32
    /// The web reads every 8th pixel (byte stride 32): columns 0, 8, 16, 24 of every row → 128 samples.
    static let pixelStride = 8

    // MARK: Pipeline

    /// Reads a bundled image file and derives its pair, off the main actor. `nil` when the file
    /// can't be decoded (the caller shows the photo's fallback pair, like the web's `catch`).
    @concurrent static func derive(contentsOf url: URL) async -> Result? {
        guard let pixels = pixels(contentsOf: url) else { return nil }
        return derive(fromRGBA: pixels)
    }

    /// 32×32 un-premultiplied sRGB RGBA bytes, row-major (the web's `getImageData` layout).
    static func pixels(contentsOf url: URL) -> [UInt8]? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        // Decode a small thumbnail instead of the full 2400px image, then scale it to 32×32.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 256,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return pixels(of: thumbnail)
    }

    /// Draws `image` stretched to 32×32 (aspect not preserved, like `drawImage(img, 0, 0, 32, 32)`) in an
    /// explicit sRGB space, so Display P3 sources are converted and clipped, then un-premultiplies.
    static func pixels(of image: CGImage) -> [UInt8]? {
        let bytesPerRow = side * 4
        var bytes = [UInt8](repeating: 0, count: side * bytesPerRow)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            // Not `.high`: its Lanczos-style filter overshoots at edges, creating samples more saturated than
            // the photo (a gray/red edge gave #C1382A next to #C0392B), and the most saturated sample wins.
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }
        unpremultiply(&bytes)
        return bytes
    }

    /// Converts premultiplied RGBA to straight alpha in place (canvas `getImageData` returns straight alpha).
    static func unpremultiply(_ bytes: inout [UInt8]) {
        for i in stride(from: 0, to: bytes.count, by: 4) {
            let a = Int(bytes[i + 3])
            guard a > 0, a < 255 else { continue }
            for c in 0..<3 {
                bytes[i + c] = UInt8(min(255, (Int(bytes[i + c]) * 255 + a / 2) / a))
            }
        }
    }

    // MARK: PM §8.9 steps 3–7

    /// Every 8th pixel of 32×32 RGBA bytes, in row order (PM §8.9 step 3).
    static func samples(fromRGBA bytes: [UInt8]) -> [SRGB8] {
        stride(from: 0, to: bytes.count, by: pixelStride * 4).map {
            SRGB8(r: bytes[$0], g: bytes[$0 + 1], b: bytes[$0 + 2])
        }
    }

    static func derive(fromRGBA bytes: [UInt8]) -> Result? {
        derive(fromSamples: samples(fromRGBA: bytes))
    }

    /// Most saturated sample = background; partner tuned against it (PM §8.9 steps 4–7). `nil` if empty.
    static func derive(fromSamples samples: [SRGB8]) -> Result? {
        // Stable sort by integer HSL saturation, descending: the first maximum wins, as in JS `sort`.
        guard var base = samples.first else { return nil }
        var best = base.hsl.s
        for sample in samples.dropFirst() where sample.hsl.s > best {
            base = sample
            best = sample.hsl.s
        }
        let hue = base.hsl.h
        let start = ColorMath.luminance(base) > 0.45
            ? SRGB8(hsl: HSL(h: hue, s: 55, l: 15))                   // dark partner, same hue
            : SRGB8(hsl: HSL(h: (hue + 35) % 360, s: 70, l: 88))      // light partner, hue +35°
        let tuned = ColorMath.tune(start, against: base)
        return Result(pair: ColorPair(background: base, foreground: tuned.color), reachedTarget: tuned.reachedTarget)
    }
}

/// Derived pairs per photo, computed once (photos are bundled; ios.md §7 Sampling).
actor DerivedPairCache {
    static let shared = DerivedPairCache()

    private var results: [Photo.ID: PhotoSampler.Result] = [:]

    /// The photo's derived pair, sampling its bundled file the first time. `nil` if it can't be read.
    func result(for photo: Photo, in bundle: Bundle = .main) async -> PhotoSampler.Result? {
        if let cached = results[photo.id] { return cached }
        guard let url = bundle.url(forResource: photo.id, withExtension: "jpg"),
              let result = await PhotoSampler.derive(contentsOf: url) else { return nil }
        results[photo.id] = result
        return result
    }
}
