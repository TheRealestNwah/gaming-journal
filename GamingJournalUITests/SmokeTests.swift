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
        XCTAssertTrue(app.tabBars.buttons["Library"].waitForExistence(timeout: 20))
        return app
    }

    /// Opens the play log of every session, reached from the Journey tab.
    private func openPlayLog(_ app: XCUIApplication) {
        app.tabBars.buttons["Journey"].tap()
        XCTAssertTrue(app.navigationBars["Journey"].waitForExistence(timeout: Self.step))
        app.navigationBars["Journey"].buttons["Play Log"].tap()
        XCTAssertTrue(app.navigationBars["Play Log"].waitForExistence(timeout: Self.step))
    }

    /// Rows combine their text into one accessibility label, so match on part of it.
    private func element(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func testOnboardingLeadsToTheLibrary() {
        let app = launch(skipOnboarding: false)
        let start = app.buttons["Begin your tale"]
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        start.tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: Self.step))
    }

    func testAddingASessionShowsItInThePlayLog() {
        let app = launch()
        openPlayLog(app)
        app.navigationBars["Play Log"].buttons["Add Session"].tap()

        let title = app.textFields["Game title"]
        XCTAssertTrue(title.waitForExistence(timeout: Self.step))
        title.tap()
        title.typeText("Balatro")
        app.navigationBars["New Session"].buttons["Save"].tap()

        XCTAssertTrue(element(containing: "Balatro", in: app).waitForExistence(timeout: Self.step))
    }

    func testStoppingTheTimerOpensThePrefilledEditor() {
        let app = launch()
        openPlayLog(app)
        app.navigationBars["Play Log"].buttons["Start Timer"].tap()

        let title = app.textFields["Game title (optional)"]
        XCTAssertTrue(title.waitForExistence(timeout: Self.step))
        title.tap()
        title.typeText("Tunic")
        app.navigationBars["Start Playing"].buttons["Start"].tap()

        let stop = app.buttons["Stop and log session"]
        XCTAssertTrue(stop.waitForExistence(timeout: Self.step))
        stop.tap()

        XCTAssertTrue(app.navigationBars["New Session"].waitForExistence(timeout: Self.step))
        XCTAssertEqual(app.textFields["Game title"].value as? String, "Tunic")
        app.navigationBars["New Session"].buttons["Save"].tap()
        XCTAssertTrue(stop.waitForNonExistence(timeout: Self.step))
    }

    func testEveryTabOpensWithDemoData() {
        let app = launch(demoData: true)
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: Self.step))

        openPlayLog(app)
        XCTAssertTrue(element(containing: "Stardew Valley", in: app).waitForExistence(timeout: Self.step))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: Self.step))
    }

    func testCreatingANotebookRecruitingAndWriting() {
        let app = launch()
        let begin = app.buttons["Begin a new tale"]
        XCTAssertTrue(begin.waitForExistence(timeout: Self.step))
        begin.tap()

        let title = app.textFields["Title, e.g. The Dragonborn's Road"]
        XCTAssertTrue(title.waitForExistence(timeout: Self.step))
        title.tap()
        title.typeText("Frostbound")
        app.textFields["Game"].tap()
        app.textFields["Game"].typeText("Dark Souls")
        app.navigationBars["New Notebook"].buttons["Create"].tap()

        let cover = element(containing: "Frostbound", in: app)
        XCTAssertTrue(cover.waitForExistence(timeout: Self.step))
        cover.tap()

        let recruit = app.buttons["Add a party member"]
        XCTAssertTrue(recruit.waitForExistence(timeout: Self.step))
        recruit.tap()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: Self.step))
        name.tap()
        name.typeText("Solaire")
        app.navigationBars["New Party Member"].buttons["Save"].tap()
        XCTAssertTrue(element(containing: "Solaire", in: app).waitForExistence(timeout: Self.step))

        app.buttons["Write in the journal"].tap()
        let entryTitle = app.textFields["Title"]
        XCTAssertTrue(entryTitle.waitForExistence(timeout: Self.step))
        entryTitle.tap()
        entryTitle.typeText("Praise the sun")
        app.buttons["Hopeful"].firstMatch.tap()
        app.navigationBars["New Entry"].buttons["Save"].tap()

        XCTAssertTrue(element(containing: "Praise the sun", in: app).waitForExistence(timeout: Self.step))
    }

    func testCharacterSheetShowsBondsFromDemoNotebook() {
        let app = launch(demoData: true)
        let notebook = element(containing: "The Dragonborn's Road", in: app)
        XCTAssertTrue(notebook.waitForExistence(timeout: Self.step))
        notebook.tap()

        let lydia = app.buttons["Lydia, Housecarl"]
        XCTAssertTrue(lydia.waitForExistence(timeout: Self.step))
        lydia.tap()

        XCTAssertTrue(app.navigationBars["Lydia"].waitForExistence(timeout: Self.step))
        XCTAssertTrue(element(containing: "Serana", in: app).waitForExistence(timeout: Self.step))
    }
}
