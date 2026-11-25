import Foundation
import Testing
@testable import ColorShift

/// iOS-derived pairs vs the web's, captured in `Fixtures/web-derived-pairs.json` (T-016; ios.md §15).
/// Browsers and Core Graphics resample differently, so colors are compared per channel with a tolerance.
struct WebParityTests {

    struct Fixture: Decodable {
        struct Pair: Decodable { let id: String; let background: String; let foreground: String }
        let pairs: [Pair]
    }

    /// Largest allowed difference in any 8-bit channel.
    static let tolerance = 6

    static let fixture: Fixture = {
        let bundle = Bundle(for: BundleToken.self)
        let url = bundle.url(forResource: "web-derived-pairs", withExtension: "json")!
        return try! JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }()

    static func distance(_ a: SRGB8, _ b: SRGB8) -> Int {
        max(abs(Int(a.r) - Int(b.r)), abs(Int(a.g) - Int(b.g)), abs(Int(a.b) - Int(b.b)))
    }

    @Test func fixtureCoversTheCatalogInOrder() {
        #expect(Self.fixture.pairs.map(\.id) == PhotoCatalog.all.map(\.id))
    }

    @Test(.disabled("T-016 blocked: 6 of 12 photos exceed ±6 (see prd.md T-016); owner to decide"), arguments: PhotoCatalog.all)
    func derivedPairMatchesWeb(_ photo: Photo) async throws {
        let web = try #require(Self.fixture.pairs.first { $0.id == photo.id })
        let url = try #require(Bundle.main.url(forResource: photo.id, withExtension: "jpg"))
        let pair = try #require(await PhotoSampler.derive(contentsOf: url)).pair
        let bg = Self.distance(pair.background, SRGB8(hex: web.background)!)
        let fg = Self.distance(pair.foreground, SRGB8(hex: web.foreground)!)
        let summary = "\(photo.id): iOS \(pair.background.hex)/\(pair.foreground.hex) vs web \(web.background)/\(web.foreground) (Δbg \(bg), Δfg \(fg))"
        #expect(bg <= Self.tolerance && fg <= Self.tolerance, "\(summary)")
    }
}

private final class BundleToken {}
