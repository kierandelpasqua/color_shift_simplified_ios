import XCTest

/// T-044: `colorshift://pair?fg=…&bg=…&photo=N` restores the pair and photo, from a cold or warm start.
final class DeepLinkTests: XCTestCase {
    static let link = URL(string: "colorshift://pair?fg=F2D27A&bg=1F3A5F&photo=3")!
    static let photo3 = "photo-1787015163482-2e06e9091258"

    /// iOS asks "Open in …?" for a custom scheme opened from outside the app; accept it.
    @MainActor
    private func open(_ url: URL) {
        XCUIDevice.shared.system.open(url)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.buttons["Open"]
        if open.waitForExistence(timeout: 3) { open.tap() }
    }

    @MainActor
    private func assertLinkApplied(_ app: XCUIApplication, _ name: String) {
        let photo = app.buttons["photoPanel"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        // The derived pair for photo 3 must not overwrite the link's colors once it loads.
        sleep(2)
        XCTAssertEqual(photo.value as? String, Self.photo3)
        app.buttons["mixerToggle"].tap()
        let fg = app.buttons["colorField.Foreground"]
        XCTAssertTrue(fg.waitForExistence(timeout: 2))
        XCTAssertEqual(fg.value as? String, "#F2D27A")
        XCTAssertEqual(app.buttons["colorField.Background"].value as? String, "#1F3A5F")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testColdStartLinkShowsPairAndPhoto() {
        let app = XCUIApplication()
        app.terminate()
        open(Self.link)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        assertLinkApplied(app, "t044-cold")
    }

    @MainActor
    func testWarmLinkShowsPairAndPhoto() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["photoPanel"].waitForExistence(timeout: 5))
        sleep(1)   // Let the first photo's derived pair apply, so the link must replace it.
        open(Self.link)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        assertLinkApplied(app, "t044-warm")
    }
}
