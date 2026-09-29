import XCTest
@testable import GamingJournal

final class EmberMotionTests: XCTestCase {
    func testEmbersAreStableAcrossCalls() {
        XCTAssertEqual(EmberMotion.embers(count: 5), EmberMotion.embers(count: 5))
        XCTAssertEqual(EmberMotion.embers(count: 0), [])
    }

    func testEmberRisesAndFades() {
        let ember = EmberMotion.Ember(x: 0.5, duration: 10, phase: 0, sway: 0, radius: 2)
        let size = CGSize(width: 100, height: 200)
        let start = ember.position(at: 0, in: size)
        let halfway = ember.position(at: 5, in: size)
        XCTAssertEqual(start.point.y, 200, accuracy: 0.001)
        XCTAssertEqual(start.fade, 1, accuracy: 0.001)
        XCTAssertEqual(halfway.point.y, 100, accuracy: 0.001)
        XCTAssertEqual(halfway.fade, 0.5, accuracy: 0.001)
        XCTAssertEqual(halfway.point.x, 50, accuracy: 0.001)
        // The cycle repeats.
        XCTAssertEqual(ember.position(at: 15, in: size).point.y, 100, accuracy: 0.001)
    }
}
