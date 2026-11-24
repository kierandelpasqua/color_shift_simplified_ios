import Foundation
import Testing
@testable import ColorShift

private func c(_ hex: String) -> SRGB8 { SRGB8(hex: hex)! }

private func makeModel(base: String = "https://colorshift.example/") -> (AppModel, UserDefaults) {
    let suite = "AppModelTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return (AppModel(defaults: defaults, webBaseURL: URL(string: base)!), defaults)
}

private let catalog = PhotoCatalog.all

struct AppModelTests {

    // MARK: Initial state (PM §6)

    @Test func initialStateMatchesWeb() {
        let (model, _) = makeModel()
        #expect(!model.controlsOpen)
        #expect(model.selectedThemes.isEmpty)
        #expect(model.photo.id == catalog[0].id)
        #expect(model.foreground.hex == "#F4C6D9")
        #expect(model.background.hex == "#16172B")
        #expect(model.mode == .wcag)
        #expect(model.hapticsEnabled)
        #expect(model.pendingDerivation == catalog[0].id)
    }

    // MARK: Navigation

    @Test func navigationWrapsAroundAndAppliesFallback() {
        let (model, _) = makeModel()
        model.navigate(-1)
        #expect(model.photo.id == catalog[11].id)
        #expect(model.foreground == catalog[11].fallback.foreground)
        #expect(model.background == catalog[11].fallback.background)
        model.navigate(1)
        #expect(model.photo.id == catalog[0].id)
        for _ in 0..<12 { model.navigate(1) }
        #expect(model.photo.id == catalog[0].id)
    }

    @Test func navigationWrapsWithinFilter() {
        let (model, _) = makeModel()
        model.toggleTheme(.objects)
        model.navigate(1)
        #expect(model.photo.id == catalog[11].id)
        model.navigate(1)
        #expect(model.photo.id == catalog[10].id)
        model.navigate(-1)
        #expect(model.photo.id == catalog[11].id)
    }

    // MARK: Filtering (PM §6, §13)

    @Test func filterResetsToFirstVisiblePhotoAndItsFallback() {
        let (model, _) = makeModel()
        model.navigate(1); model.navigate(1)
        model.toggleTheme(.animals)
        #expect(model.photo.id == catalog[6].id)
        #expect(model.foreground == catalog[6].fallback.foreground)
        model.toggleTheme(.urban)
        #expect(model.selectedThemes == [.animals, .urban])
        #expect(model.visiblePhotos.map(\.id) == [2, 3, 6, 7].map { catalog[$0].id })   // catalog order
        #expect(model.photo.id == catalog[2].id)
    }

    @Test func deselectingLastThemeAndAllBothMeanAll() {
        let (model, _) = makeModel()
        model.toggleTheme(.people)
        model.toggleTheme(.people)
        #expect(model.selectedThemes.isEmpty)
        #expect(model.visiblePhotos.count == 12)
        model.toggleTheme(.people); model.toggleTheme(.abstract)
        model.navigate(1)
        model.toggleTheme(nil)
        #expect(model.selectedThemes.isEmpty)
        #expect(model.photo.id == catalog[0].id)
        #expect(model.foreground == catalog[0].fallback.foreground)
    }

    // MARK: Taps (PM §13)

    @Test func tapsCloseTheOpenDrawerInsteadOfNavigating() {
        let (model, _) = makeModel()
        model.controlsOpen = true
        model.photoTapped()
        #expect(!model.controlsOpen)
        #expect(model.photo.id == catalog[0].id)
        model.photoTapped()
        #expect(model.photo.id == catalog[1].id)

        model.controlsOpen = true
        model.photoSwiped(-1)
        #expect(!model.controlsOpen)
        #expect(model.photo.id == catalog[1].id)
        model.photoSwiped(-1)
        #expect(model.photo.id == catalog[0].id)

        model.controlsOpen = true
        model.specimenTapped()
        #expect(!model.controlsOpen)
    }

    // MARK: Derivation

    @Test func derivedPairReplacesFallbackOnce() {
        let (model, _) = makeModel()
        let pair = ColorPair(background: c("#1F3A5F"), foreground: c("#F2D27A"))
        model.photoDidDerive(pair, for: catalog[0].id)
        #expect(model.foreground == pair.foreground && model.background == pair.background)
        #expect(model.pendingDerivation == nil)
        // A second (duplicate) delivery doesn't overwrite later edits.
        model.swap()
        model.photoDidDerive(pair, for: catalog[0].id)
        #expect(model.foreground == pair.background)
    }

    @Test func staleDerivationIsIgnored() {
        let (model, _) = makeModel()
        model.navigate(1)
        model.photoDidDerive(ColorPair(background: c("#000000"), foreground: c("#FFFFFF")), for: catalog[0].id)
        #expect(model.foreground == catalog[1].fallback.foreground)
    }

    @Test func failedDerivationUsesFallback() {
        let (model, _) = makeModel()
        model.foreground = c("#123456")
        model.photoDidDerive(nil, for: catalog[0].id)
        #expect(model.foreground == catalog[0].fallback.foreground)
    }

    // MARK: Deep links

    @Test func deepLinkSkipsDerivationExactlyOnce() throws {
        let (model, _) = makeModel()
        #expect(model.apply(deepLink: URL(string: "colorshift://pair?fg=f2d27a&bg=1F3A5F&photo=3")!))
        #expect(model.photo.id == catalog[3].id)
        #expect(model.foreground.hex == "#F2D27A" && model.background.hex == "#1F3A5F")
        #expect(model.preserveLinkedColors)
        let derived = ColorPair(background: c("#000000"), foreground: c("#FFFFFF"))
        model.photoDidDerive(derived, for: catalog[3].id)
        #expect(model.foreground.hex == "#F2D27A")              // skipped
        #expect(!model.preserveLinkedColors)
        model.navigate(1)
        model.photoDidDerive(derived, for: catalog[4].id)
        #expect(model.foreground.hex == "#FFFFFF")               // next one applies
    }

    @Test func deepLinkToCurrentAlreadyDerivedPhotoDoesNotLeaveASkipBehind() {
        let (model, _) = makeModel()
        model.photoDidDerive(ColorPair(background: c("#000000"), foreground: c("#FFFFFF")), for: catalog[0].id)
        model.apply(deepLink: URL(string: "colorshift://pair?fg=F2D27A&bg=1F3A5F&photo=0")!)
        #expect(model.foreground.hex == "#F2D27A")
        #expect(!model.preserveLinkedColors)
        model.navigate(1)
        let derived = ColorPair(background: c("#222222"), foreground: c("#EEEEEE"))
        model.photoDidDerive(derived, for: catalog[1].id)
        #expect(model.foreground.hex == "#EEEEEE")
    }

    @Test func deepLinkClearsFilterAndUsesFullCatalogIndex() {
        let (model, _) = makeModel()
        model.toggleTheme(.objects)
        model.apply(deepLink: URL(string: "colorshift://pair?fg=F2D27A&bg=1F3A5F&photo=5")!)
        #expect(model.selectedThemes.isEmpty)
        #expect(model.photo.id == catalog[5].id)
        #expect(model.catalogIndex == 5)
    }

    @Test func deepLinkWithOneBadColorAppliesTheOtherAndDoesNotSkip() {
        let (model, _) = makeModel()
        model.apply(deepLink: URL(string: "colorshift://pair?fg=GGGGGG&bg=1F3A5F&photo=2")!)
        #expect(model.photo.id == catalog[2].id)
        #expect(model.foreground == catalog[2].fallback.foreground)
        #expect(model.background.hex == "#1F3A5F")
        #expect(!model.preserveLinkedColors)
    }

    @Test func deepLinkWithOutOfRangePhotoLeavesPhotoAlone() {
        let (model, _) = makeModel()
        model.navigate(1)
        model.apply(deepLink: URL(string: "colorshift://pair?fg=F2D27A&bg=1F3A5F&photo=12")!)
        #expect(model.photo.id == catalog[1].id)
        #expect(model.foreground.hex == "#F2D27A")
    }

    @Test(arguments: [
        ("colorshift://pair?fg=F2D27A&bg=1f3a5f&photo=11", "#F2D27A", "#1F3A5F", 11),
        ("https://colorshift.example/?fg=F2D27A&bg=1F3A5F&photo=0", "#F2D27A", "#1F3A5F", 0),
        ("https://COLORSHIFT.example/app?bg=1F3A5F&fg=F2D27A", "#F2D27A", "#1F3A5F", 0),   // missing photo = 0
        ("colorshift://pair?fg=%23F2D27A&bg=1F3A5F&photo=", nil, "#1F3A5F", 0),           // "#" (encoded) not allowed
        ("colorshift://pair?fg=F2D27&bg=1F3A5F0&photo=-1", nil, nil, nil),
        ("colorshift://pair?photo=1.0", nil, nil, nil),
        ("colorshift://pair?photo=0x3", nil, nil, nil),
        ("colorshift://pair?photo=%203", nil, nil, nil),
    ] as [(String, String?, String?, Int?)])
    func deepLinkParsing(url: String, fg: String?, bg: String?, photo: Int?) throws {
        let link = try #require(DeepLink(url: URL(string: url)!, webBaseURL: URL(string: "https://colorshift.example/")!))
        #expect(link.foreground?.hex == fg)
        #expect(link.background?.hex == bg)
        #expect(link.photoIndex == photo)
    }

    @Test(arguments: [
        "colorshift://other?fg=F2D27A&bg=1F3A5F",
        "https://evil.example/?fg=F2D27A&bg=1F3A5F",
        "http://colorshift.example/?fg=F2D27A&bg=1F3A5F",
        "mailto:someone@colorshift.example",
    ])
    func foreignURLsAreRejected(_ url: String) {
        let (model, _) = makeModel()
        #expect(!model.apply(deepLink: URL(string: url)!))
        #expect(model.foreground.hex == "#F4C6D9")
    }

    // MARK: Colors

    @Test func swapExchangesColors() {
        let (model, _) = makeModel()
        model.swap()
        #expect(model.foreground.hex == "#16172B" && model.background.hex == "#F4C6D9")
    }

    @Test func movingOneSliderChangesOnlyThatColor() {
        let (model, _) = makeModel()
        model.foreground = c("#F2D27A")
        model.background = c("#1F3A5F")
        model.setChannel(.foreground, .lightness, 60)
        #expect(model.foreground.hsl.l == 60)
        #expect(model.background.hex == "#1F3A5F")          // untouched color keeps its hex
    }

    @Test func settingAChannelToItsCurrentValueDoesNotDrift() {
        let (model, _) = makeModel()
        model.foreground = c("#F2D27A")                      // HSL rebuild would give #F2D178
        model.setChannel(.foreground, .hue, 44)
        model.setChannel(.foreground, .saturation, 82)
        model.setChannel(.foreground, .lightness, 71)
        #expect(model.foreground.hex == "#F2D27A")
    }

    @Test func sliderMoveRebuildsFromIntegerHSLLikeWeb() {
        let (model, _) = makeModel()
        model.foreground = c("#F2D27A")
        model.setChannel(.foreground, .hue, 45)
        #expect(model.foreground.hex == "#F2D378")           // PM §8.12 hslToHex(45, 82, 71)
    }

    @Test func jumpReachesOrReportsMiss() {
        let (model, _) = makeModel()
        model.foreground = c("#8899AA"); model.background = c("#1F3A5F")
        #expect(model.jump(to: 4.5))
        #expect(model.foreground.hex == "#97A6B5")
        #expect(model.wcag >= 4.5)

        model.foreground = c("#777777"); model.background = c("#777777")
        #expect(!model.jump(to: 7))
        #expect(model.wcag < 7)
    }

    @Test func contrastValuesFollowColors() {
        let (model, _) = makeModel()
        model.foreground = c("#F2D27A"); model.background = c("#1F3A5F")
        #expect(abs(model.wcag - 7.806) < 0.0005)
        #expect(abs(model.apca - -73.164) < 0.001)
    }

    // MARK: Share and export (PM §14)

    @Test func shareURLUsesWebFormatAndFullCatalogIndex() {
        let (model, _) = makeModel()
        model.toggleTheme(.objects)
        model.navigate(1)                                     // filtered index 1 = catalog index 11
        model.foreground = c("#F2D27A"); model.background = c("#1F3A5F")
        #expect(model.shareURL.absoluteString == "https://colorshift.example/?fg=F2D27A&bg=1F3A5F&photo=11")
    }

    @Test func markdownMatchesWebOutput() {
        let (model, _) = makeModel()
        model.foreground = c("#F2D27A"); model.background = c("#1F3A5F")
        // Generated by running the web's template in node with photo 0 and this pair.
        let web = "# Color Shift\n\n![Mountain ridges under a vivid pink and blue sky](https://images.unsplash.com/photo-1500964757637-c85e8a162699?auto=format&fit=crop&w=1800&q=88)\n\nPhoto by [Simon Berger](https://unsplash.com/@simon_berger) on Unsplash.\n\n- Foreground: `#F2D27A`\n- Background: `#1F3A5F`\n- WCAG contrast: **7.81:1**\n"
        #expect(model.markdown == web)
        #expect(model.markdownFileName == "color-shift-F2D27A-1F3A5F.md")
    }

    @Test(arguments: [
        (1.125, "1.13"), (1.005, "1.00"), (2.675, "2.67"), (9.995, "9.99"), (7.806, "7.81"),
        (21.0, "21.00"), (4.5, "4.50"), (0.125, "0.13"), (99.995, "100.00"),
    ])
    func formatRatioMatchesJSToFixed(value: Double, expected: String) {
        #expect(ColorMath.formatRatio(value) == expected)
    }

    // MARK: Persistence

    @Test func hapticsPreferencePersists() {
        let (model, defaults) = makeModel()
        model.hapticsEnabled = false
        model.save()
        let reloaded = AppModel(defaults: defaults, webBaseURL: URL(string: "https://colorshift.example/")!)
        #expect(!reloaded.hapticsEnabled)
    }
}
