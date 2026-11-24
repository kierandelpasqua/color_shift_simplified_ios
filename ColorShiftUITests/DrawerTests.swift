import XCTest

final class DrawerTests: XCTestCase {
    @MainActor
    func testToggleOpensAndClosesDrawer() {
        let app = XCUIApplication()
        app.launch()
        let toggle = app.buttons["mixerToggle"]
        let deck = app.descendants(matching: .any)["controlDeck"]

        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertFalse(deck.exists)
        XCTAssertEqual(toggle.label, "Open color controls")

        toggle.tap()
        XCTAssertTrue(deck.waitForExistence(timeout: 2))
        XCTAssertEqual(toggle.label, "Close color controls")

        toggle.tap()
        XCTAssertTrue(deck.waitForNonExistence(timeout: 2))
    }

    @MainActor
    func testTappingPhotoWhileOpenClosesDrawerWithoutNavigating() {
        let app = XCUIApplication()
        app.launch()
        let photo = app.buttons["photoPanel"]
        let deck = app.descendants(matching: .any)["controlDeck"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        let first = photo.value as? String

        app.buttons["mixerToggle"].tap()
        XCTAssertTrue(deck.waitForExistence(timeout: 2))

        photo.tap()
        XCTAssertTrue(deck.waitForNonExistence(timeout: 2))
        XCTAssertEqual(photo.value as? String, first, "closing the drawer must not change the photo")

        photo.tap()
        XCTAssertNotEqual(photo.value as? String, first, "with the drawer closed, a tap shows the next photo")
    }
}
