import XCTest

/// T-052: App Store screenshots with real photos and their derived pairs. Each test saves one attachment named
/// `store-N-…`; export them from the result bundle into `docs/store/screenshots/<device>/`. Set a clean status
/// bar first: `xcrun simctl status_bar <device> override --time 9:41 …`.
final class StoreScreenshots: XCTestCase {

    @MainActor
    private func launch(showing index: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let photo = app.buttons["photoPanel"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        for _ in 0..<index { photo.tap() }
        XCTAssertEqual(photo.value as? String, PhotoPanelTests.ids[index])
        sleep(1)   // Reveal and derived pair.
        return app
    }

    @MainActor
    private func save(_ app: XCUIApplication, _ name: String) {
        sleep(1)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    private func openDrawer(_ app: XCUIApplication) {
        app.buttons["mixerToggle"].tap()
        XCTAssertTrue(app.buttons["chip.All"].waitForExistence(timeout: 3))
    }

    /// The photo and its pair, drawer closed.
    @MainActor func test1Hero() {
        let app = launch(showing: 0)
        save(app, "store-1-photo-pair")
    }

    /// The controls over a vivid photo.
    @MainActor func test2Controls() {
        let app = launch(showing: 6)
        openDrawer(app)
        save(app, "store-2-controls")
    }

    /// Contrast meter after Jump to AAA.
    @MainActor func test3Contrast() {
        let app = launch(showing: 4)
        openDrawer(app)
        let jump = app.buttons["jumpButton"]
        let deck = app.descendants(matching: .any)["controlDeck"]
        var swipes = 0
        while !jump.isHittable, swipes < 4 { deck.swipeUp(velocity: .slow); swipes += 1 }
        XCTAssertEqual(jump.label, "Jump to WCAG AAA contrast")
        jump.tap()
        XCTAssertEqual(app.buttons["tick.AAA"].value as? String, "passes")
        save(app, "store-3-contrast")
    }

    /// APCA readout.
    @MainActor func test4APCA() {
        let app = launch(showing: 10)
        openDrawer(app)
        let apca = app.buttons["mode.APCA"]
        let deck = app.descendants(matching: .any)["controlDeck"]
        var swipes = 0
        while !apca.isHittable, swipes < 4 { deck.swipeUp(velocity: .slow); swipes += 1 }
        apca.tap()
        save(app, "store-4-apca")
    }

    /// Theme filter.
    @MainActor func test5Themes() {
        let app = launch(showing: 0)
        openDrawer(app)
        app.buttons["chip.Urban"].tap()
        XCTAssertEqual(app.buttons["photoPanel"].value as? String, PhotoPanelTests.ids[2])
        sleep(1)
        save(app, "store-5-themes")
    }
}
