import XCTest

/// Quick checks of the core flows, run on every pull request.
final class SmokeTests: XCTestCase {
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
        XCTAssertTrue(app.tabBars.buttons["Journal"].waitForExistence(timeout: 20))
        return app
    }

    /// Rows combine their text into one accessibility label, so match on part of it.
    private func element(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func testOnboardingLeadsToTheJournal() {
        let app = launch(skipOnboarding: false)
        let start = app.buttons["Get Started"]
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        start.tap()
        XCTAssertTrue(app.navigationBars["Journal"].waitForExistence(timeout: 5))
    }

    func testAddingASessionShowsItInTheJournal() {
        let app = launch()
        app.navigationBars["Journal"].buttons["Add Session"].tap()

        let title = app.textFields["Game title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Balatro")
        app.navigationBars["New Session"].buttons["Save"].tap()

        XCTAssertTrue(element(containing: "Balatro", in: app).waitForExistence(timeout: 5))
    }

    func testStoppingTheTimerOpensThePrefilledEditor() {
        let app = launch()
        app.navigationBars["Journal"].buttons["Start Timer"].tap()

        let title = app.textFields["Game title (optional)"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Tunic")
        app.navigationBars["Start Playing"].buttons["Start"].tap()

        let stop = app.buttons["Stop and log session"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()

        XCTAssertTrue(app.navigationBars["New Session"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Game title"].value as? String, "Tunic")
        app.navigationBars["New Session"].buttons["Save"].tap()
        XCTAssertTrue(stop.waitForNonExistence(timeout: 5))
    }

    func testEveryTabOpensWithDemoData() {
        let app = launch(demoData: true)
        XCTAssertTrue(element(containing: "Stardew Valley", in: app).waitForExistence(timeout: 5))

        app.tabBars.buttons["Games"].tap()
        XCTAssertTrue(app.navigationBars["Games"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "Hades", in: app).waitForExistence(timeout: 5))

        app.tabBars.buttons["Stats"].tap()
        XCTAssertTrue(app.navigationBars["Stats"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }
}
