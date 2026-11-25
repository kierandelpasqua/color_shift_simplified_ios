import XCTest

/// Captures the open deck at several text sizes, scrolled top to bottom (T-040). Screenshots are attachments.
final class DynamicTypeScreenshots: XCTestCase {
    @MainActor private func capture(_ category: String, name: String) {
        let app = XCUIApplication()
        app.launchArguments += ["-openControlsOnLaunch", "YES", "-UIPreferredContentSizeCategoryName", category]
        app.launch()
        XCTAssertTrue(app.buttons["mixerToggle"].waitForExistence(timeout: 5))
        let deck = app.scrollViews["controlDeck"].exists ? app.scrollViews["controlDeck"] : app.descendants(matching: .any)["controlDeck"]
        for page in 0..<5 {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "\(name)-\(page)"
            shot.lifetime = .keepAlways
            add(shot)
            deck.swipeUp(velocity: .slow)
        }
    }

    @MainActor func testLarge() { capture("UICTContentSizeCategoryL", name: "large") }
    @MainActor func testAX3() { capture("UICTContentSizeCategoryAccessibilityXL", name: "ax3") }
    @MainActor func testAX5() { capture("UICTContentSizeCategoryAccessibilityXXXL", name: "ax5") }
}
