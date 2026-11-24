import XCTest

final class SliderTests: XCTestCase {
    @MainActor
    func testForegroundLightnessSliderChangesOnlyForeground() {
        let app = XCUIApplication()
        app.launchArguments += ["-openControlsOnLaunch", "YES"]
        app.launch()
        let fg = app.buttons["colorField.Foreground"]
        let bg = app.buttons["colorField.Background"]
        let slider = app.sliders["Foreground lightness"]
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
