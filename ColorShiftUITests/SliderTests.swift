import XCTest

final class SliderTests: XCTestCase {
    @MainActor
    func testForegroundLightnessSliderChangesOnlyForeground() {
        let app = XCUIApplication()
        app.launchArguments += ["-openControlsOnLaunch", "YES", "-disablePhotoDerivation", "YES"]
        app.launch()
        let fg = app.buttons["colorField.Foreground"]
        let bg = app.buttons["colorField.Background"]
        let slider = app.descendants(matching: .any)["slider.Foreground lightness"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        XCTAssertEqual(slider.value as? String, "87 percent")   // #F4C6D9 → l 87

        // A touch on the track (left of the thumb) moves the value down to about the touch point.
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let after = Int((slider.value as? String ?? "").split(separator: " ").first ?? "") ?? -1
        XCTAssertTrue((30...70).contains(after), "tap at mid-row gave \(after)")
        XCTAssertNotEqual(fg.value as? String, "#F4C6D9")
        XCTAssertEqual(bg.value as? String, "#16172B", "the untouched color keeps its hex")
    }
}

final class SliderScrollTests: XCTestCase {
    /// Regression: a vertical swipe that starts on a slider must scroll the deck, not move the slider.
    @MainActor
    func testVerticalSwipeOnSliderDoesNotChangeColor() {
        let app = XCUIApplication()
        app.launchArguments += ["-openControlsOnLaunch", "YES", "-disablePhotoDerivation", "YES"]
        app.launch()
        let slider = app.descendants(matching: .any)["slider.Foreground lightness"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        let before = slider.value as? String
        // Real touch drags from the visible part of the slider. (XCUI's element `swipeDown()` on a slider half
        // scrolled under the deck's top edge, as on iPhone Duo, changes the value even though a touch drag
        // from the same point doesn't, so drag by coordinates.)
        let deck = app.descendants(matching: .any)["controlDeck"]
        func dragVertically(by dy: CGFloat) {
            let y = max(slider.frame.midY, deck.frame.minY + 12) - slider.frame.minY
            let start = slider.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: slider.frame.width / 2, dy: y))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: dy)),
                        withVelocity: .slow, thenHoldForDuration: 0)
        }
        dragVertically(by: -250)
        dragVertically(by: 250)
        XCTAssertEqual(app.buttons["colorField.Foreground"].value as? String, "#F4C6D9")
        XCTAssertEqual(slider.value as? String, before)
    }

    @MainActor
    func testHorizontalDragMovesSlider() {
        let app = XCUIApplication()
        app.launchArguments += ["-openControlsOnLaunch", "YES", "-disablePhotoDerivation", "YES"]
        app.launch()
        let slider = app.descendants(matching: .any)["slider.Foreground lightness"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        let start = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        let end = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertNotEqual(app.buttons["colorField.Foreground"].value as? String, "#F4C6D9")
    }
}
