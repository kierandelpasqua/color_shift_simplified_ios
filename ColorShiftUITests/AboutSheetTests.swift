import XCTest

/// T-045: the About sheet opens from the brand row and shows the Haptics toggle, every photo credit, both
/// font licenses and the privacy link.
final class AboutSheetTests: XCTestCase {

    @MainActor
    private func openAbout() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-openControlsOnLaunch", "YES"]
        app.launch()
        let about = app.buttons["aboutButton"]
        XCTAssertTrue(about.waitForExistence(timeout: 5))
        about.tap()
        XCTAssertTrue(app.switches["hapticsToggle"].waitForExistence(timeout: 3))
        return app
    }

    @MainActor
    func testAboutShowsToggleAndEveryCredit() {
        let app = openAbout()
        let list = app.collectionViews.firstMatch
        for id in PhotoPanelTests.ids {
            let credit = app.descendants(matching: .any)["credit.\(id)"]
            var swipes = 0
            while !credit.isHittable, swipes < 8 { list.swipeUp(velocity: .slow); swipes += 1 }
            XCTAssertTrue(credit.exists, "credit for \(id)")
            XCTAssertTrue(credit.label.hasPrefix("Photo by "), credit.label)
        }
        for element in [app.descendants(matching: .any)["unsplashLink"], app.descendants(matching: .any)["privacyLink"],
                        app.buttons["font.Manrope-OFL"], app.buttons["font.DMMono-OFL"]] {
            var swipes = 0
            while !element.exists || !element.isHittable, swipes < 8 { list.swipeUp(velocity: .slow); swipes += 1 }
            XCTAssertTrue(element.exists, element.identifier)
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "t045-about-bottom"
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testHapticsTogglePersistsAcrossLaunches() {
        var app = openAbout()
        let toggle = app.switches["hapticsToggle"]
        let before = toggle.value as? String
        toggle.switches.firstMatch.tap()
        XCTAssertNotEqual(toggle.value as? String, before)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "t045-about-top"
        shot.lifetime = .keepAlways
        add(shot)

        app.terminate()
        app = openAbout()
        XCTAssertNotEqual(app.switches["hapticsToggle"].value as? String, before, "setting must persist")
        // Restore the original value for other tests.
        app.switches["hapticsToggle"].switches.firstMatch.tap()
        XCTAssertEqual(app.switches["hapticsToggle"].value as? String, before)
    }

    @MainActor
    func testFontLicenseOpensOFLText() {
        let app = openAbout()
        let list = app.collectionViews.firstMatch
        let manrope = app.buttons["font.Manrope-OFL"]
        var swipes = 0
        while !manrope.isHittable, swipes < 8 { list.swipeUp(velocity: .slow); swipes += 1 }
        manrope.tap()
        let license = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'SIL OPEN FONT LICENSE'")).firstMatch
        XCTAssertTrue(license.waitForExistence(timeout: 3))
    }
}
