import XCTest
@testable import GamingJournal

final class RibbonShelfTests: XCTestCase {
    private let suite = "RibbonShelfTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testLaysAndTakesOutTheRibbonPerJournal() {
        let shelf = RibbonShelf(defaults: defaults)
        let journalID = UUID()
        let mark = RibbonMark(entryID: UUID(), part: 2)
        XCTAssertNil(shelf.mark(for: journalID))

        shelf.setMark(mark, for: journalID)
        XCTAssertEqual(shelf.mark(for: journalID), mark)
        XCTAssertNil(shelf.mark(for: UUID()))

        shelf.setMark(nil, for: journalID)
        XCTAssertNil(shelf.mark(for: journalID))
    }

    func testMarksTheFirstBlockOnAPage() {
        let entryID = UUID()
        let page = JournalPager.Page(index: 3, blocks: [
            JournalPager.Block(entryID: entryID, part: 1, showsHeading: false, heading: "Day 1", text: "…", showsPhotos: false),
        ])
        XCTAssertEqual(RibbonMark(page: page), RibbonMark(entryID: entryID, part: 1))
        XCTAssertNil(RibbonMark(page: JournalPager.Page(index: 0, blocks: [])))
    }
}
