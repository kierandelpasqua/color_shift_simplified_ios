import Foundation
import ImageIO
import Testing
@testable import ColorShift

struct PhotoCatalogTests {

    /// Copied from the web's `src/App.tsx` photo URLs, in order (ios.md I9). Do not reorder.
    static let webIDs = [
        "photo-1500964757637-c85e8a162699",
        "photo-1615729947596-a598e5de0ab3",
        "photo-1787012055240-859e0bd53875",
        "photo-1787015163482-2e06e9091258",
        "photo-1557053910-d9eadeed1c58",
        "photo-1617690032703-f991ed0e0ee6",
        "photo-1534599864649-c66531e112eb",
        "photo-1689758380989-f92c89619a2d",
        "photo-1550859492-d5da9d8e45f3",
        "photo-1548746450-48dbc4747adc",
        "photo-1760445798933-4d3945d0b06b",
        "photo-1558769673-de478227d1f5",
    ]

    @Test func hasTwelvePhotosInWebOrder() {
        #expect(PhotoCatalog.all.count == 12)
        #expect(PhotoCatalog.all.map(\.id) == Self.webIDs)
    }

    @Test func twoPhotosPerThemeInChipOrder() {
        let themes = PhotoCatalog.all.map(\.theme)
        #expect(themes == Theme.allCases.flatMap { [$0, $0] })
    }

    @Test func firstPhotoMatchesWebInitialState() {
        // PM §6: initial foreground #F4C6D9, background #16172B.
        let first = PhotoCatalog.all[0]
        #expect(first.fallback.foreground.hex == "#F4C6D9")
        #expect(first.fallback.background.hex == "#16172B")
    }

    @Test(arguments: PhotoCatalog.all)
    func fallbackPairMeetsAA(_ photo: Photo) {
        let ratio = ColorMath.contrast(photo.fallback.foreground, photo.fallback.background)
        #expect(ratio >= ColorMath.aa, "\(photo.id): \(ratio)")
    }

    @Test func webImageURLMatchesWebFormat() {
        #expect(PhotoCatalog.all[0].webImageURL.absoluteString
            == "https://images.unsplash.com/photo-1500964757637-c85e8a162699?auto=format&fit=crop&w=1800&q=88")
        #expect(PhotoCatalog.all[0].fileName == "photo-1500964757637-c85e8a162699.jpg")
    }

    @Test func filteringKeepsCatalogOrderAndAllMeansEmpty() {
        #expect(PhotoCatalog.visible(for: []).map(\.id) == Self.webIDs)
        let filtered = PhotoCatalog.visible(for: [.abstract, .animals])
        #expect(filtered.map(\.id) == Array(Self.webIDs[6...9]))
    }

    @Test func catalogIndexIsFullCatalogPosition() {
        let filtered = PhotoCatalog.visible(for: [.objects])
        #expect(PhotoCatalog.catalogIndex(of: filtered[1]) == 11)
    }

    // MARK: T-014: bundled files, credits, measured aspects

    @Test(arguments: PhotoCatalog.all)
    func bundledFileMatchesAspect(_ photo: Photo) throws {
        let url = try #require(Bundle.main.url(forResource: photo.id, withExtension: "jpg"), "\(photo.fileName) missing")
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let props = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let width = try #require(props[kCGImagePropertyPixelWidth] as? Double)
        let height = try #require(props[kCGImagePropertyPixelHeight] as? Double)
        #expect(max(width, height) >= 2000, "\(photo.id) is only \(width)×\(height)")
        let measured = width / height
        #expect(abs(photo.aspect - measured) / measured < 0.005, "\(photo.id): \(photo.aspect) vs \(measured)")
    }

    @Test(arguments: PhotoCatalog.all)
    func everyPhotoHasACredit(_ photo: Photo) {
        #expect(!photo.photographer.isEmpty && !photo.handle.isEmpty && !photo.handle.hasPrefix("@"))
        #expect(photo.photographerURL.absoluteString
            == "https://unsplash.com/@\(photo.handle)?utm_source=color_shift&utm_medium=referral")
    }

    @Test func unsplashLinkHasReferral() {
        #expect(Photo.unsplashURL.absoluteString == "https://unsplash.com/?utm_source=color_shift&utm_medium=referral")
    }

    @Test func measuredAspectsKeepWebLayoutBuckets() {
        // Web hand-entered aspects, in catalog order; the mobile photo share must not change.
        let web = [1.56, 0.67, 1.33, 0.67, 0.67, 0.67, 1.5, 0.67, 1.5, 0.67, 1.5, 0.67]
        for (photo, webAspect) in zip(PhotoCatalog.all, web) {
            #expect(ColorMath.layoutShares(aspect: photo.aspect).mobile == ColorMath.layoutShares(aspect: webAspect).mobile,
                    "\(photo.id)")
        }
    }
}
