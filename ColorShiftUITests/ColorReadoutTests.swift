import XCTest

final class ColorReadoutTests: XCTestCase {
    @MainActor
    func testSwapExchangesColors() {
        let app = XCUIApplication()
        app.launchArguments += ["-openControlsOnLaunch", "YES", "-disablePhotoDerivation", "YES"]
        app.launch()
        let fg = app.buttons["colorField.Foreground"]
        let bg = app.buttons["colorField.Background"]
        XCTAssertTrue(fg.waitForExistence(timeout: 5))
        XCTAssertEqual(fg.value as? String, "#F4C6D9")
        XCTAssertEqual(bg.value as? String, "#16172B")

        app.buttons["swapButton"].tap()
        XCTAssertEqual(fg.value as? String, "#16172B")
        XCTAssertEqual(bg.value as? String, "#F4C6D9")
    }

    @MainActor
    func testTappingAFieldOpensTheSystemColorPicker() {
        let app = XCUIApplication()
        app.launchArguments += ["-openControlsOnLaunch", "YES", "-disablePhotoDerivation", "YES"]
        app.launch()
        let fg = app.buttons["colorField.Foreground"]
        XCTAssertTrue(fg.waitForExistence(timeout: 5))
        fg.tap()
        // Something only the system picker has: its Grid / Spectrum / Sliders tabs.
        let pickerTab = app.buttons.matching(NSPredicate(format: "label IN {'Grid', 'Spectrum', 'Sliders'}")).firstMatch
        XCTAssertTrue(pickerTab.waitForExistence(timeout: 5), "the system color picker did not appear")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
