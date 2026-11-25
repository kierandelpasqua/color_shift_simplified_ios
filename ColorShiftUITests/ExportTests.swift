import XCTest

final class ExportUITests: XCTestCase {
    @MainActor
    func testCopyLinkShowsToast() {
        let app = XCUIApplication()
        app.launchArguments += ["-openControlsOnLaunch", "YES", "-disablePhotoDerivation", "YES"]
        app.launch()
        let copy = app.buttons["copyLinkButton"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        copy.tap()
        XCTAssertTrue(app.staticTexts["copiedToast"].waitForExistence(timeout: 2))
        XCTAssertEqual(copy.label, "Copied")
        // Gone after 1.6 s (+ the 180 ms fade).
        XCTAssertTrue(app.staticTexts["copiedToast"].waitForNonExistence(timeout: 4))
        XCTAssertEqual(copy.label, "Copy link")
    }

    @MainActor
    func testMarkdownOpensShareSheet() {
        let app = XCUIApplication()
        app.launchArguments += ["-openControlsOnLaunch", "YES", "-disablePhotoDerivation", "YES"]
        app.launch()
        let markdown = app.buttons["markdownButton"]
        XCTAssertTrue(markdown.waitForExistence(timeout: 5))
        markdown.tap()
        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "share sheet did not appear")
        // The sheet's header names the file, and it offers Save to Files.
        let fileName = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "color-shift-F4C6D9-16172B.md")).firstMatch
        XCTAssertTrue(fileName.waitForExistence(timeout: 3), "share sheet should name the .md file")
        XCTAssertTrue(app.descendants(matching: .any)["Save to Files"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.lifetime = .keepAlways
        add(shot)
    }
}
