import XCTest
@testable import GamingJournal

final class DictationTextTests: XCTestCase {
    func testIntoAnEmptyEntryStartsASentence() {
        XCTAssertEqual(DictationText.append("we reached the grove", to: ""), "We reached the grove")
    }

    func testContinuingALineAddsASpace() {
        XCTAssertEqual(DictationText.append("and the druids", to: "We reached the grove"), "We reached the grove and the druids")
        XCTAssertEqual(DictationText.append("and the druids", to: "We reached the grove   "), "We reached the grove and the druids")
    }

    func testAfterASentenceItCapitalises() {
        XCTAssertEqual(DictationText.append("the druids watched", to: "We reached the grove."), "We reached the grove. The druids watched")
        XCTAssertEqual(DictationText.append("what now", to: "Did it work?"), "Did it work? What now")
    }

    func testAfterALineBreakItStartsTheLine() {
        XCTAssertEqual(DictationText.append("next morning", to: "Night fell.\n"), "Night fell.\nNext morning")
    }

    func testBlankDictationChangesNothing() {
        XCTAssertEqual(DictationText.append("  \n", to: "Unchanged "), "Unchanged ")
    }
}
