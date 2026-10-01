import XCTest

/// Quick checks of the core flows, run on every pull request.
final class SmokeTests: XCTestCase {
    /// How long to wait for each screen or row. Waits end as soon as it appears, so this only
    /// matters on a slow, busy CI runner, where 5 seconds proved too short (#81).
    private static let step: TimeInterval = 15

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(demoData: Bool = false, skipOnboarding: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
            + (demoData ? ["-demoData"] : [])
            + (skipOnboarding ? ["-onboarding.completed", "YES"] : [])
        app.launch()
        if !skipOnboarding { return app }
        XCTAssertTrue(app.buttons["Begin a new journal"].waitForExistence(timeout: 20))
        return app
    }

    /// Keep real app renders available in CI even when the smoke tests pass.
    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Rows combine their text into one accessibility label, so match on part of it.
    private func element(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Taps a field and types into it. A tap that lands while a sheet is still sliding in can miss
    /// the field, so tap again (a few times at most) until it reports keyboard focus (#111).
    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: Self.step))
        for _ in 0..<3 {
            field.tap()
            if hasKeyboardFocus(field, within: 1) { break }
        }
        field.typeText(text)
    }

    private func hasKeyboardFocus(_ field: XCUIElement, within timeout: TimeInterval) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        repeat {
            if (field.value(forKey: "hasKeyboardFocus") as? Bool) == true { return true }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date.now < deadline
        return false
    }

    func testOnboardingLeadsToTheShelf() {
        let app = launch(skipOnboarding: false)
        let start = app.buttons["Open the first page"]
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        start.tap()
        XCTAssertTrue(app.buttons["Begin a new journal"].waitForExistence(timeout: Self.step))
    }

    func testBeginningAJournalAndWritingAnEntry() {
        let app = launch()
        app.buttons["Begin a new journal"].tap()

        type("Eira Stormborn", into: app.textFields["characterName"])
        app.navigationBars["New Journal"].buttons["Begin"].tap()

        let quill = app.buttons["Write a new entry"]
        XCTAssertTrue(quill.waitForExistence(timeout: Self.step))
        XCTAssertTrue(element(containing: "The Journal of Eira Stormborn", in: app).exists)
        quill.tap()

        type("16th of Last Seed", into: app.textFields["inGameDate"])
        type("Praise the sun", into: app.textViews["entryBody"])
        capture("04-writer", in: app)
        app.buttons["Done"].tap()

        XCTAssertTrue(element(containing: "Praise the sun", in: app).waitForExistence(timeout: Self.step))
        XCTAssertTrue(element(containing: "16th of Last Seed", in: app).exists)
    }

    func testDemoJournalOpensOnItsLatestPage() {
        let app = launch(demoData: true)
        let journal = element(containing: "Eira Stormborn", in: app)
        XCTAssertTrue(journal.waitForExistence(timeout: Self.step))
        journal.tap()

        // The latest page ends with the latest entry (which may have started on the page before).
        let ending = element(containing: "never learned", in: app)
        XCTAssertTrue(ending.waitForExistence(timeout: Self.step), "Latest page not shown: " + app.debugDescription)
        capture("05-journal-latest-page", in: app)
        XCTAssertFalse(app.buttons["Next page"].isEnabled)
        app.buttons["Back to journals"].tap()
        XCTAssertTrue(app.buttons["Begin a new journal"].waitForExistence(timeout: Self.step))
    }

    func testSearchOpensTheJournalAtTheEntry() {
        let app = launch(demoData: true)
        type("dragonstone", into: app.textFields["Search the journals"])
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "wall that spoke")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: Self.step), "No search result: " + app.debugDescription)
        result.tap()
        XCTAssertTrue(app.buttons["Write a new entry"].waitForExistence(timeout: Self.step))
        XCTAssertTrue(element(containing: "The Journal of Eira Stormborn", in: app).exists)
    }

    func testContentsTurnsToTheFirstEntry() {
        let app = launch(demoData: true)
        capture("01-shelf", in: app)
        let journal = element(containing: "Eira Stormborn", in: app)
        XCTAssertTrue(journal.waitForExistence(timeout: Self.step))
        journal.tap()
        let contents = app.buttons["contents"]
        XCTAssertTrue(contents.waitForExistence(timeout: Self.step))
        contents.tap()

        XCTAssertTrue(app.navigationBars["Contents"].waitForExistence(timeout: Self.step))
        let first = app.buttons.matching(identifier: "contentsEntry").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: Self.step))
        capture("03-contents", in: app)
        first.tap()

        // The sheet closes on the first page.
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.navigationBars["Contents"])
        wait(for: [closed], timeout: Self.step)
        XCTAssertFalse(app.buttons["Previous page"].isEnabled)
        capture("02-journal-first-page", in: app)
    }

    func testSettingsOpenFromTheShelf() {
        let app = launch()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: Self.step))
        app.navigationBars["Settings"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Begin a new journal"].waitForExistence(timeout: Self.step))
    }
}
