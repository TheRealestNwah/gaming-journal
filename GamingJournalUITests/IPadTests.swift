#if os(iOS)
import XCTest
import UIKit

final class IPadTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad-specific layout acceptance")
        XCUIDevice.shared.orientation = .portrait
    }
    override func tearDownWithError() throws { XCUIDevice.shared.orientation = .portrait }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLargeTextReaderKeepsNavigationAndWritingReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-demoData", "-onboarding.completed", "YES",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "-AppleInterfaceStyle", "Dark"]
        app.launch()
        let journal = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Eira Stormborn")).firstMatch
        XCTAssertTrue(journal.waitForExistence(timeout: 20))
        journal.tap()
        let quill = app.buttons["Write a new entry"]
        XCTAssertTrue(quill.waitForExistence(timeout: 15))
        XCTAssertTrue(quill.isHittable)
        XCTAssertTrue(app.buttons["Back to journals"].isHittable)
        XCTAssertTrue(app.buttons["contents"].isHittable)
        let entry = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "never learned")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        // This short entry should fit within a screen at the largest text size.
        // Applying Dynamic Type twice makes it several screens tall.
        XCTAssertLessThan(entry.frame.height, app.frame.height)
        capture("ipad-large-text-dark-reader", app)
        quill.tap()
        XCTAssertTrue(app.textViews["entryBody"].waitForExistence(timeout: 15))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(quill.waitForExistence(timeout: 15))
    }

    func testRotationKeepsLatestEntryAndChangesToFacingPages() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-demoData", "-longDemoData", "-onboarding.completed", "YES"]
        app.launch()
        let journal = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Eira Stormborn")).firstMatch
        XCTAssertTrue(journal.waitForExistence(timeout: 20))
        capture("ipad-portrait-shelf", app)
        journal.tap()
        let ending = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "never learned")).firstMatch
        XCTAssertTrue(ending.waitForExistence(timeout: 15))
        capture("ipad-portrait-reader", app)
        XCUIDevice.shared.orientation = .landscapeLeft
        let position = app.staticTexts["pagePosition"]
        let landscape = expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        wait(for: [landscape], timeout: 15)
        XCTAssertTrue(ending.exists)
        XCTAssertFalse(app.buttons["Next page"].isEnabled)
        capture("ipad-landscape-spread", app)
        app.buttons["contents"].tap()
        let first = app.buttons.matching(identifier: "contentsEntry").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        first.tap()
        let firstPage = expectation(for: NSPredicate(format: "enabled == false"), evaluatedWith: app.buttons["Previous page"])
        wait(for: [firstPage], timeout: 15)
        let spread = expectation(for: NSPredicate(format: "label BEGINSWITH %@", "pages 1–2"), evaluatedWith: position)
        wait(for: [spread], timeout: 15)
        capture("ipad-landscape-first-spread", app)
        XCUIDevice.shared.orientation = .portrait
        let single = expectation(for: NSPredicate(format: "label BEGINSWITH %@", "page 1 of"), evaluatedWith: position)
        wait(for: [single], timeout: 15)
        XCTAssertFalse(app.buttons["Previous page"].isEnabled)
    }
}
#endif
