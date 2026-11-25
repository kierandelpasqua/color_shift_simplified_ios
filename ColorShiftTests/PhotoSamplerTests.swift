import CoreGraphics
import Foundation
import Testing
@testable import ColorShift

private func c(_ hex: String) -> SRGB8 { SRGB8(hex: hex)! }

/// A synthetic image: `top` over the upper half, `bottom` over the lower half.
private func image(top: SRGB8, bottom: SRGB8, size: Int = 320) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    func fill(_ color: SRGB8, _ rect: CGRect) {
        context.setFillColor(CGColor(srgbRed: CGFloat(color.r) / 255, green: CGFloat(color.g) / 255,
                                     blue: CGFloat(color.b) / 255, alpha: 1))
        context.fill(rect)
    }
    let half = CGFloat(size) / 2
    fill(bottom, CGRect(x: 0, y: 0, width: CGFloat(size), height: half))   // CG origin is bottom-left
    fill(top, CGRect(x: 0, y: half, width: CGFloat(size), height: half))
    return context.makeImage()!
}

struct PhotoSamplerTests {

    // Expected pairs were produced by the web's own functions (src/App.tsx `rgbToHsl` … `tuneToContrast`,
    // run in Node with the PM §8.9 steps) on the same samples.

    @Test(arguments: [
        ("#3366CC", "#EEE9FB"),   // dark base → light partner, hue +35°
        ("#F2D27A", "#3B3011"),   // light base (luminance > 0.45) → dark partner, same hue
    ])
    func solidImage(base: String, partner: String) throws {
        let pixels = try #require(PhotoSampler.pixels(of: image(top: c(base), bottom: c(base))))
        let samples = PhotoSampler.samples(fromRGBA: pixels)
        #expect(samples.count == 128)
        #expect(Set(samples) == [c(base)])
        let result = try #require(PhotoSampler.derive(fromRGBA: pixels))
        #expect(result.pair.background.hex == base)
        #expect(result.pair.foreground.hex == partner)
        #expect(result.reachedTarget)
    }

    @Test func twoToneImagePicksTheSaturatedHalf() throws {
        let pixels = try #require(PhotoSampler.pixels(of: image(top: c("#808080"), bottom: c("#C0392B"))))
        let samples = PhotoSampler.samples(fromRGBA: pixels)
        #expect(samples.filter { $0 == c("#808080") }.count == 64)
        #expect(samples.filter { $0 == c("#C0392B") }.count == 64)
        let result = try #require(PhotoSampler.derive(fromRGBA: pixels))
        #expect(result.pair.background.hex == "#C0392B")
        #expect(result.pair.foreground.hex == "#F7E9CF")
    }

    @Test func samplesAreEveryEighthPixelInRowOrder() {
        // 32×32 RGBA where each pixel's red byte is its column and green byte its row.
        var bytes = [UInt8](repeating: 255, count: 32 * 32 * 4)
        for row in 0..<32 { for col in 0..<32 {
            let i = (row * 32 + col) * 4
            bytes[i] = UInt8(col); bytes[i + 1] = UInt8(row)
        } }
        let samples = PhotoSampler.samples(fromRGBA: bytes)
        #expect(samples.count == 128)
        #expect(samples.prefix(5).map { [$0.r, $0.g] } == [[0, 0], [8, 0], [16, 0], [24, 0], [0, 1]])
    }

    @Test func saturationTiesKeepTheFirstSample() throws {
        // JS `sort` is stable: with equal saturation the earliest sample stays first.
        let samples = (0..<128).map { $0.isMultiple(of: 2) ? c("#00FF00") : c("#FF0000") }
        let result = try #require(PhotoSampler.derive(fromSamples: samples))
        #expect(result.pair.background.hex == "#00FF00")
        #expect(result.pair.foreground.hex == "#113B11")
    }

    @Test func emptySamplesGiveNoPair() {
        #expect(PhotoSampler.derive(fromSamples: []) == nil)
    }

    @Test func unpremultiplyRestoresStraightAlpha() {
        var bytes: [UInt8] = [64, 32, 0, 128, 10, 20, 30, 255, 0, 0, 0, 0]
        PhotoSampler.unpremultiply(&bytes)
        #expect(bytes == [128, 64, 0, 128, 10, 20, 30, 255, 0, 0, 0, 0])
    }

    // MARK: Catalog

    @Test(arguments: PhotoCatalog.all)
    func everyCatalogPhotoDerivesAPair(_ photo: Photo) async throws {
        let url = try #require(Bundle.main.url(forResource: photo.id, withExtension: "jpg"))
        let result = try #require(await PhotoSampler.derive(contentsOf: url))
        let ratio = ColorMath.contrast(result.pair.foreground, result.pair.background)
        // ≥ 4.5:1, or the miss is reported (never a silent miss; ios.md §14).
        #expect(result.reachedTarget == (ratio >= ColorMath.aa), "\(photo.id): \(ratio)")
    }

    @Test func cacheReturnsTheSameResult() async throws {
        let cache = DerivedPairCache()
        let photo = PhotoCatalog.all[0]
        let first = try #require(await cache.result(for: photo))
        let second = try #require(await cache.result(for: photo))
        #expect(first == second)
    }
}
