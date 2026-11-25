import XCTest

final class ContrastTests: XCTestCase {
    private func ratio(_ element: XCUIElement) -> Double {
        // Accessibility value "7.81 to 1".
        Double((element.value as? String ?? "").split(separator: " ").first ?? "") ?? -1
    }

    @MainActor
    func testJumpToAAReachesAtLeast4_5() {
        let app = XCUIApplication()
        app.launchArguments += ["-openControlsOnLaunch", "YES", "-disablePhotoDerivation", "YES"]
        app.launch()
        let score = app.staticTexts["contrastScore"]
        let lightness = app.descendants(matching: .any)["slider.Foreground lightness"]
        XCTAssertTrue(lightness.waitForExistence(timeout: 5))

        // Darken the light foreground toward the dark background until AA fails.
        lightness.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
        let jump = app.buttons["jumpButton"]
        if !jump.isHittable { app.swipeUp() }
        XCTAssertTrue(score.waitForExistence(timeout: 2))
        XCTAssertLessThan(ratio(score), 4.5, "setup should break AA")
        XCTAssertEqual(jump.label, "Jump to WCAG AA contrast")

        jump.tap()
        XCTAssertGreaterThanOrEqual(ratio(score), 4.5)
        XCTAssertEqual(app.buttons["tick.AA"].value as? String, "passes")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testAPCAModeShowsLc() {
        let app = XCUIApplication()
        app.launchArguments += ["-openControlsOnLaunch", "YES", "-disablePhotoDerivation", "YES"]
        app.launch()
        let apca = app.buttons["mode.APCA"]
        XCTAssertTrue(apca.waitForExistence(timeout: 5))
        if !apca.isHittable { app.swipeUp() }
        apca.tap()
        // #F4C6D9 on #16172B: real APCA −78.254 → "78 L c".
        XCTAssertEqual(app.staticTexts["contrastScore"].value as? String, "78 L c")
        XCTAssertTrue(apca.isSelected)
    }
}
