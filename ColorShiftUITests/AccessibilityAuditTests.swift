import XCTest

/// `performAccessibilityAudit()` on the main screen and the open drawer (T-042).
/// Two documented exemptions:
/// - The "Aa" specimen is a fixed size on purpose: its 80pt minimum already exceeds AX5 (ios.md §8).
/// - Contrast for elements not fully inside the deck's visible area: they're scrolled out (and the audit
///   measures them against the canvas behind) or under iOS 26's scroll-edge fade.
/// - Contrast for the unselected WCAG/APCA segment. Its 44pt hit area spans the segment capsule and the deck
///   above and below it, and the audit compares those two dark fills (1.29:1). Measured from the audit's
///   own element screenshot: text #A6A8AD is 5.83:1 on the capsule (#2B2C31) and 7.53:1 on the deck.
final class AccessibilityAuditTests: XCTestCase {
    private func audit(_ app: XCUIApplication) throws {
        let deck = app.descendants(matching: .any)["controlDeck"]
        let visibleDeck = deck.exists ? deck.frame.insetBy(dx: 0, dy: 24) : .null
        try app.performAccessibilityAudit { issue in
            guard let element = issue.element else { return false }
            if issue.auditType == .dynamicType, element.label == "Aa" { return true }
            if issue.auditType == .contrast, !visibleDeck.isNull, !visibleDeck.contains(element.frame) { return true }
            if issue.auditType == .contrast, element.identifier.hasPrefix("mode."), !element.isSelected { return true }
            print("AUDIT-FAIL \(issue.compactDescription) | id=\(element.identifier) label=\(element.label) frame=\(element.frame) deck=\(visibleDeck)")
            return false
        }
    }

    @MainActor
    func testMainScreenPassesAudit() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["mixerToggle"].waitForExistence(timeout: 5))
        try audit(app)
    }

    @MainActor
    func testOpenDrawerPassesAudit() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-openControlsOnLaunch", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["chip.All"].waitForExistence(timeout: 5))
        try audit(app)
        app.swipeUp()
        try audit(app)
        app.swipeUp()
        try audit(app)
    }

    @MainActor
    func testPhotoIsLabelledWithItsAltText() {
        let app = XCUIApplication()
        app.launch()
        let photo = app.buttons["photoPanel"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        XCTAssertEqual(photo.label, "Mountain ridges under a vivid pink and blue sky")
    }

    @MainActor
    func testSlidersAreAdjustableWithRoleInLabel() {
        let app = XCUIApplication()
        app.launchArguments += ["-openControlsOnLaunch", "YES"]
        app.launch()
        let slider = app.descendants(matching: .any)["slider.Foreground lightness"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        XCTAssertEqual(slider.label, "Foreground lightness")
        XCTAssertEqual(slider.value as? String, "87 percent")
    }
}
