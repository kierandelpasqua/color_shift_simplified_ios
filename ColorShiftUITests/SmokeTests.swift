import XCTest

/// T-046 smoke flow with real photos and derived pairs (ios.md §15): launch → tap photo → open drawer →
/// select a theme → Jump to AA → copy link. Run on iPhone 17e, 18 Pro, 18 Pro Max and Duo.
final class SmokeTests: XCTestCase {
    @MainActor private func ratio(_ element: XCUIElement) -> Double {
        Double((element.value as? String ?? "").split(separator: " ").first ?? "") ?? -1
    }

    @MainActor
    func testSmokeFlow() {
        let app = XCUIApplication()
        app.launch()

        // Launch: first photo, then one tap shows the second.
        let photo = app.buttons["photoPanel"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        XCTAssertEqual(photo.value as? String, PhotoPanelTests.ids[0])
        photo.tap()
        XCTAssertEqual(photo.value as? String, PhotoPanelTests.ids[1])

        // Open the drawer.
        app.buttons["mixerToggle"].tap()
        let abstract = app.buttons["chip.Abstract"]
        XCTAssertTrue(abstract.waitForExistence(timeout: 3))

        // Select a theme: the first Abstract photo (catalog index 8).
        if !abstract.isHittable { app.scrollViews.containing(.button, identifier: "chip.All").firstMatch.swipeLeft() }
        abstract.tap()
        XCTAssertEqual(photo.value as? String, PhotoPanelTests.ids[8])

        // Break AA by darkening the light foreground, then Jump to AA.
        let lightness = app.descendants(matching: .any)["slider.Foreground lightness"]
        XCTAssertTrue(lightness.waitForExistence(timeout: 2))
        sleep(1)   // Let the photo's derived pair apply first.
        if !lightness.isHittable { app.swipeUp() }
        lightness.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
        let score = app.staticTexts["contrastScore"]
        let jump = app.buttons["jumpButton"]
        if !jump.isHittable { app.swipeUp() }
        XCTAssertLessThan(ratio(score), 4.5, "setup should break AA")
        XCTAssertEqual(jump.label, "Jump to WCAG AA contrast")
        jump.tap()
        XCTAssertGreaterThanOrEqual(ratio(score), 4.5)

        // Copy link: toast confirms.
        let copy = app.buttons["copyLinkButton"]
        if !copy.isHittable { app.swipeDown() }
        copy.tap()
        XCTAssertTrue(app.descendants(matching: .any)["copiedToast"].waitForExistence(timeout: 2))

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "t046-smoke"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
