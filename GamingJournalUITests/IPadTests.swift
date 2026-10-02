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
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testRotationKeepsLatestEntryAndChangesToFacingPages() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-demoData", "-onboarding.completed", "YES"]
        app.launch()
        let journal = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Eira Stormborn")).firstMatch
        XCTAssertTrue(journal.waitForExistence(timeout: 20))
        capture("ipad-portrait-shelf", app)
        journal.tap()
        let ending = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "never learned")).firstMatch
        XCTAssertTrue(ending.waitForExistence(timeout: 15))
        capture("ipad-portrait-reader", app)
        XCUIDevice.shared.orientation = .landscapeLeft
        let position = app.staticTexts["pagePosition"]
        let spread = expectation(for: NSPredicate(format: "label BEGINSWITH %@", "Pages"), evaluatedWith: position)
        wait(for: [spread], timeout: 15)
        XCTAssertTrue(ending.exists)
        XCTAssertFalse(app.buttons["Next page"].isEnabled)
        capture("ipad-landscape-spread", app)
        app.buttons["contents"].tap()
        let first = app.buttons.matching(identifier: "contentsEntry").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        first.tap()
        let firstPage = expectation(for: NSPredicate(format: "enabled == false"), evaluatedWith: app.buttons["Previous page"])
        wait(for: [firstPage], timeout: 15)
        capture("ipad-landscape-first-spread", app)
        XCUIDevice.shared.orientation = .portrait
        let single = expectation(for: NSPredicate(format: "label BEGINSWITH %@", "Page 1 of"), evaluatedWith: position)
        wait(for: [single], timeout: 15)
        XCTAssertFalse(app.buttons["Previous page"].isEnabled)
    }
}
#endif
