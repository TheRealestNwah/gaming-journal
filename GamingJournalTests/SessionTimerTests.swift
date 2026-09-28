import XCTest
@testable import GamingJournal

final class TimerStateTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func at(_ seconds: TimeInterval) -> Date {
        t0.addingTimeInterval(seconds)
    }

    func testElapsedWhileRunning() {
        let state = TimerState(gameTitle: "  Hades ", startedAt: t0)
        XCTAssertEqual(state.gameTitle, "Hades")
        XCTAssertFalse(state.isPaused)
        XCTAssertEqual(state.elapsed(at: at(90)), 90)
        XCTAssertEqual(state.elapsed(at: at(-10)), 0)
    }

    func testPausesAreNotCounted() {
        var state = TimerState(gameTitle: "Hades", startedAt: t0)
        state.pause(at: at(600))
        XCTAssertTrue(state.isPaused)
        XCTAssertEqual(state.elapsed(at: at(5000)), 600)

        state.resume(at: at(1200))
        XCTAssertEqual(state.elapsed(at: at(1500)), 900)

        state.pause(at: at(1800))
        state.pause(at: at(9999))
        XCTAssertEqual(state.elapsed(at: at(9999)), 1200)
    }

    func testResumeWhileRunningIsIgnored() {
        var state = TimerState(gameTitle: "Hades", startedAt: t0)
        state.resume(at: at(300))
        XCTAssertEqual(state.elapsed(at: at(600)), 600)
    }

    func testMinutesRoundToNearestWithOneMinuteFloor() {
        let state = TimerState(gameTitle: "", startedAt: t0)
        XCTAssertEqual(state.minutes(at: t0), 0)
        XCTAssertEqual(state.minutes(at: at(10)), 1)
        XCTAssertEqual(state.minutes(at: at(89)), 1)
        XCTAssertEqual(state.minutes(at: at(90)), 2)
        XCTAssertEqual(state.minutes(at: at(3600)), 60)
    }

    func testDraftPrefillsEditor() {
        var state = TimerState(gameTitle: "Celeste", startedAt: t0)
        state.pause(at: at(45 * 60))
        let draft = state.draft(at: at(99_999))
        XCTAssertEqual(draft.gameTitle, "Celeste")
        XCTAssertEqual(draft.startDate, t0)
        XCTAssertEqual(draft.durationMinutes, 45)
    }

    func testCodableRoundTrip() throws {
        var state = TimerState(gameTitle: "Tunic", startedAt: t0)
        state.pause(at: at(120))
        let decoded = try JSONDecoder().decode(TimerState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded, state)
    }
}

final class LiveTimerTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "LiveTimerTests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    @MainActor
    func testStateSurvivesRelaunch() {
        let start = Date(timeIntervalSince1970: 2_000_000)
        let timer = LiveTimer(defaults: defaults)
        XCTAssertFalse(timer.isActive)
        timer.start(gameTitle: "Balatro", at: start)
        timer.pause(at: start.addingTimeInterval(300))

        let relaunched = LiveTimer(defaults: defaults)
        XCTAssertEqual(relaunched.state, timer.state)
        XCTAssertEqual(relaunched.state?.elapsed(at: .distantFuture), 300)
    }

    @MainActor
    func testStopKeepsTimerUntilCleared() {
        let start = Date(timeIntervalSince1970: 2_000_000)
        let timer = LiveTimer(defaults: defaults)
        timer.start(gameTitle: "Balatro", at: start)

        let draft = timer.stop(at: start.addingTimeInterval(30 * 60))
        XCTAssertEqual(draft?.durationMinutes, 30)
        XCTAssertEqual(timer.state?.isPaused, true)
        XCTAssertTrue(timer.isActive)

        timer.clear()
        XCTAssertFalse(timer.isActive)
        XCTAssertNil(LiveTimer(defaults: defaults).state)
    }

    @MainActor
    func testStopWithoutTimerReturnsNil() {
        XCTAssertNil(LiveTimer(defaults: defaults).stop())
    }
}

final class ClockFormatTests: XCTestCase {
    func testClock() {
        XCTAssertEqual(PlaytimeFormatter.clock(fromSeconds: -3), "0:00")
        XCTAssertEqual(PlaytimeFormatter.clock(fromSeconds: 245), "4:05")
        XCTAssertEqual(PlaytimeFormatter.clock(fromSeconds: 3723), "1:02:03")
    }
}
