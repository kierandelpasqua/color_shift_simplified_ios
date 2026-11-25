import Foundation
import Testing
@testable import ColorShift

/// iOS-derived pairs vs the web's, captured in `Fixtures/web-derived-pairs.json` (T-016; ios.md §15).
/// Sampling on iOS can't reproduce the web's single-pixel pick (T-016: 6/12 photos off by up to 68 per channel),
/// so the app uses the web's captured pairs from the catalog; this checks what the app actually applies.
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

    /// What the app applies for each photo (`DerivedPairCache`, T-016 decision: the web's captured pairs).
    @Test(arguments: PhotoCatalog.all)
    func derivedPairMatchesWeb(_ photo: Photo) async throws {
        let web = try #require(Self.fixture.pairs.first { $0.id == photo.id })
        let result = try #require(await DerivedPairCache().result(for: photo))
        let bg = Self.distance(result.pair.background, SRGB8(hex: web.background)!)
        let fg = Self.distance(result.pair.foreground, SRGB8(hex: web.foreground)!)
        #expect(bg <= Self.tolerance && fg <= Self.tolerance,
                "\(photo.id): iOS \(result.pair.background.hex)/\(result.pair.foreground.hex) vs web \(web.background)/\(web.foreground)")
        // The web misses 4.5:1 silently on some photos; iOS reports it (ios.md §14).
        #expect(result.reachedTarget == (ColorMath.contrast(result.pair.foreground, result.pair.background) >= ColorMath.aa))
    }

    /// The catalog's `derived` table is exactly the captured fixture.
    @Test func catalogTableEqualsFixture() {
        for (photo, web) in zip(PhotoCatalog.all, Self.fixture.pairs) {
            #expect(photo.derived?.background.hex == web.background, "\(photo.id)")
            #expect(photo.derived?.foreground.hex == web.foreground, "\(photo.id)")
        }
    }
}

private final class BundleToken {}
