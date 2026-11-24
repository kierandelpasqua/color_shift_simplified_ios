import XCTest

final class ThemeChipTests: XCTestCase {
    @MainActor
    func testTogglingAChipFiltersPhotosAndSelects() {
        let app = XCUIApplication()
        app.launchArguments += ["-openControlsOnLaunch", "YES"]
        app.launch()

        let all = app.buttons["chip.All"]
        let animals = app.buttons["chip.Animals"]
        let photo = app.buttons["photoPanel"]
        XCTAssertTrue(animals.waitForExistence(timeout: 5))
        XCTAssertTrue(all.isSelected)
        XCTAssertFalse(animals.isSelected)

        animals.tap()
        XCTAssertTrue(animals.isSelected)
        XCTAssertFalse(all.isSelected)
        // First Animals photo in catalog order (PM §14 #6).
        XCTAssertEqual(photo.value as? String, "photo-1534599864649-c66531e112eb")

        all.tap()
        XCTAssertTrue(all.isSelected)
        XCTAssertFalse(animals.isSelected)
        XCTAssertEqual(photo.value as? String, "photo-1500964757637-c85e8a162699")
    }
}
