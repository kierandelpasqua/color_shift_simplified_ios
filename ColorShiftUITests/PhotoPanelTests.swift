import XCTest

/// T-022: one tap advances exactly one photo; swipes move ±1 (PM §13; ios.md §14 double-advance fix).
final class PhotoPanelTests: XCTestCase {

    /// The web catalog order (ios.md I9); the photo panel's accessibility value is the photo ID.
    static let ids = [
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

    @MainActor
    private func launch() -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        app.launch()
        let photo = app.buttons["photoPanel"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        XCTAssertEqual(photo.value as? String, Self.ids[0])
        return (app, photo)
    }

    @MainActor
    func testOneTapAdvancesExactlyOnePhoto() {
        let (_, photo) = launch()
        for step in 1...3 {
            photo.tap()
            XCTAssertEqual(photo.value as? String, Self.ids[step], "tap \(step) must advance exactly one photo")
        }
    }

    @MainActor
    func testSwipeLeftShowsNextAndRightShowsPrevious() {
        let (_, photo) = launch()
        photo.swipeLeft()
        XCTAssertEqual(photo.value as? String, Self.ids[1], "swipe left → next, once")
        photo.swipeLeft()
        XCTAssertEqual(photo.value as? String, Self.ids[2])
        photo.swipeRight()
        XCTAssertEqual(photo.value as? String, Self.ids[1], "swipe right → previous, once")
        photo.swipeRight()
        photo.swipeRight()
        XCTAssertEqual(photo.value as? String, Self.ids[11], "previous from the first photo wraps to the last")
    }

    @MainActor
    func testSwipeWhileDrawerOpenOnlyClosesIt() {
        let (app, photo) = launch()
        let deck = app.descendants(matching: .any)["controlDeck"]
        app.buttons["mixerToggle"].tap()
        XCTAssertTrue(deck.waitForExistence(timeout: 2))
        photo.swipeLeft()
        XCTAssertTrue(deck.waitForNonExistence(timeout: 2))
        XCTAssertEqual(photo.value as? String, Self.ids[0], "closing the drawer must not change the photo")
    }

    @MainActor
    func testCreditShowsPhotographerAndDoesNotAdvance() {
        let (app, photo) = launch()
        let credit = app.links["photoCredit"]
        XCTAssertTrue(credit.waitForExistence(timeout: 2))
        XCTAssertEqual(credit.label, "Photo by Simon Berger on Unsplash")
        XCTAssertGreaterThanOrEqual(credit.frame.height, 44)
        XCTAssertEqual(photo.value as? String, Self.ids[0])
    }
}
