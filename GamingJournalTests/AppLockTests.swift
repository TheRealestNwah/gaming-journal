import XCTest
@testable import GamingJournal

final class AppLockTests: XCTestCase {
    private final class FakeAuthenticator: Authenticating {
        var succeeds = true
        var reasons: [String] = []
        let method = "Face ID"

        func authenticate(reason: String) async -> Bool {
            reasons.append(reason)
            return succeeds
        }
    }

    private let suite = "AppLockTests"
    private var defaults: UserDefaults!
    private var authenticator: FakeAuthenticator!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        authenticator = FakeAuthenticator()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func makeLock() -> AppLock {
        AppLock(defaults: defaults, authenticator: authenticator)
    }

    func testOffByDefaultAndNeverLocks() {
        let lock = makeLock()
        XCTAssertFalse(lock.isEnabled)
        XCTAssertFalse(lock.isLocked)
        lock.seal()
        XCTAssertFalse(lock.isLocked)
        XCTAssertFalse(AppLock.isEnabled(in: defaults))
    }

    func testTurningOnNeedsTheOwnerAndPersists() async {
        let lock = makeLock()
        authenticator.succeeds = false
        let refused = await lock.setEnabled(true)
        XCTAssertFalse(refused)
        XCTAssertFalse(lock.isEnabled)

        authenticator.succeeds = true
        let accepted = await lock.setEnabled(true)
        XCTAssertTrue(accepted)
        XCTAssertTrue(lock.isEnabled)
        XCTAssertTrue(AppLock.isEnabled(in: defaults))
        // Turning on while using the app doesn't lock you out on the spot.
        XCTAssertFalse(lock.isLocked)
        XCTAssertEqual(authenticator.reasons, ["Lock your journal", "Lock your journal"])
    }

    func testOpensSealedWhenOnAndUnlocksOnlyWithTheOwner() async {
        defaults.set(true, forKey: AppLock.enabledKey)
        let lock = makeLock()
        XCTAssertTrue(lock.isLocked)

        authenticator.succeeds = false
        await lock.unlock()
        XCTAssertTrue(lock.isLocked)

        authenticator.succeeds = true
        await lock.unlock()
        XCTAssertFalse(lock.isLocked)

        lock.seal()
        XCTAssertTrue(lock.isLocked)
    }

    func testUnlockingWhenOpenAsksNothing() async {
        let lock = makeLock()
        await lock.unlock()
        XCTAssertTrue(authenticator.reasons.isEmpty)
    }

    func testTurningOffAlsoNeedsTheOwner() async {
        defaults.set(true, forKey: AppLock.enabledKey)
        let lock = makeLock()
        authenticator.succeeds = false
        await lock.setEnabled(false)
        XCTAssertTrue(lock.isEnabled)
        authenticator.succeeds = true
        await lock.setEnabled(false)
        XCTAssertFalse(lock.isEnabled)
        XCTAssertFalse(AppLock.isEnabled(in: defaults))
        XCTAssertEqual(authenticator.reasons.last, "Stop locking your journal")
    }
}
