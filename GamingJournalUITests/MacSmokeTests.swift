#if os(macOS)
import XCTest

final class MacSmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(demo: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "YES", "-onboarding.completed", "YES",
            "-ApplePersistenceIgnoreState", "YES", "-NSTreatUnknownArgumentsAsOpen", "NO"]
            + (demo ? ["-demoData", "YES"] : [])
        app.launch()
        app.activate()
        let opened = app.windows.buttons["Begin a new journal"].waitForExistence(timeout: 20)
        capture("mac-launch", app)
        XCTAssertTrue(opened, app.debugDescription)
        return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func testCreateJournalWriteAndReadEntry() {
        let app = launch()
        app.windows.buttons["Begin a new journal"].click()
        let name = app.windows.textFields["characterName"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.click()
        name.typeText("Mac traveller")
        app.windows.buttons["Begin"].click()
        let quill = app.windows.buttons["Write a new entry"]
        XCTAssertTrue(quill.waitForExistence(timeout: 15))
        quill.click()
        let body = app.windows.textViews["entryBody"]
        XCTAssertTrue(body.waitForExistence(timeout: 15))
        body.click()
        body.typeText("A page written beside the campfire.")
        capture("mac-writer", app)
        app.windows.buttons["Done"].click()
        XCTAssertTrue(app.windows.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "A page written beside")).firstMatch.waitForExistence(timeout: 15))
        capture("mac-reader", app)
    }
    func testShelfSearchContentsAndSettings() {
        let app = launch(demo: true)
        capture("mac-shelf", app)
        app.windows.buttons["Search"].click()
        let search = app.windows.textFields["Search the journals"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        search.click()
        search.typeText("dragonstone")
        let result = app.windows.buttons.matching(NSPredicate(format: "label CONTAINS %@", "wall that spoke")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 15))
        result.click()
        XCTAssertTrue(app.windows.buttons["contents"].waitForExistence(timeout: 15))
        app.windows.buttons["contents"].click()
        let first = app.windows.buttons.matching(identifier: "contentsEntry").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        capture("mac-contents", app)
        first.click()
        XCTAssertTrue(app.windows.buttons["Back to journals"].waitForExistence(timeout: 15))
        app.windows.buttons["Back to journals"].click()
        app.windows.buttons["Settings"].click()
        XCTAssertTrue(app.windows.buttons["Export Backup"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.windows.buttons["Import Backup"].exists)
        capture("mac-settings", app)
        app.windows.buttons["Close"].click()
    }
}
#endif
