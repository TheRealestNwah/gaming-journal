import XCTest
@testable import GamingJournal

final class JournalPagerTests: XCTestCase {
    private func item(_ body: String, heading: String = "16th of Last Seed", photos: Bool = false) -> JournalPager.Item {
        JournalPager.Item(id: UUID(), heading: heading, body: body, hasPhotos: photos)
    }

    /// Words of `length` letters, so line counts are easy to reason about.
    private func words(_ count: Int, length: Int = 4) -> String {
        Array(repeating: String(repeating: "a", count: length), count: count).joined(separator: " ")
    }

    func testEmptyJournalStillHasOnePage() {
        let pages = JournalPager(charactersPerLine: 30, linesPerPage: 20).pages(for: [])
        XCTAssertEqual(pages.count, 1)
        XCTAssertTrue(pages[0].blocks.isEmpty)
    }

    func testWrapBreaksAtWordsAndSplitsOverlongWords() {
        let pager = JournalPager(charactersPerLine: 10, linesPerPage: 20)
        XCTAssertEqual(pager.wrap("aaaa bbbb cccc"), ["aaaa bbbb", "cccc"])
        XCTAssertEqual(pager.wrap("abcdefghijklmno"), ["abcdefghij", "klmno"])
        XCTAssertEqual(pager.wrap(""), [])
    }

    func testShortEntriesShareAPage() {
        let pager = JournalPager(charactersPerLine: 30, linesPerPage: 20)
        let pages = pager.pages(for: [item("One short line."), item("Another short line.")])
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].blocks.map(\.showsHeading), [true, true])
    }

    func testLongEntryCarriesOverWithoutRepeatingItsHeading() throws {
        // 9 words of 4 letters fill a 14-character line two at a time: 45 lines of text.
        let pager = JournalPager(charactersPerLine: 14, linesPerPage: 20)
        let long = item(words(90))
        let pages = pager.pages(for: [long])
        XCTAssertGreaterThan(pages.count, 1)
        XCTAssertEqual(pages.flatMap(\.blocks).filter(\.showsHeading).count, 1)
        XCTAssertTrue(pages.allSatisfy { $0.blocks.allSatisfy { $0.entryID == long.id } })
        XCTAssertEqual(pages.flatMap(\.blocks).map(\.part), Array(0..<pages.count))
        // Every word makes it onto a page, in order.
        let words = pages.flatMap(\.blocks).flatMap { $0.text.split(whereSeparator: \.isWhitespace) }
        XCTAssertEqual(words.count, 90)
    }

    func testNoPageOverflows() {
        let pager = JournalPager(charactersPerLine: 20, linesPerPage: 15)
        let items = (0..<12).map { index in item(words(5 + index * 7), photos: index % 4 == 0) }
        for page in pager.pages(for: items) {
            var lines = 0
            for (position, block) in page.blocks.enumerated() {
                if block.showsHeading {
                    lines += (position == 0 ? 0 : JournalPager.entryGap) + JournalPager.headingLines
                }
                lines += JournalPager.paragraphs(in: block.text).reduce(0) { $0 + pager.lineCount(of: $1) }
                if block.showsPhotos { lines += JournalPager.photoLines }
            }
            XCTAssertLessThanOrEqual(lines, pager.linesPerPage, "page \(page.index + 1) overflows")
        }
    }

    func testHeadingIsNeverLeftAloneAtTheFootOfAPage() {
        let pager = JournalPager(charactersPerLine: 20, linesPerPage: 12)
        // The first entry leaves one line free: too little for the next heading and its text.
        let first = item(words(4 * 9))
        let second = item("A new day.")
        let pages = pager.pages(for: [first, second])
        let secondStart = pages.first { $0.blocks.contains { $0.entryID == second.id } }
        XCTAssertEqual(secondStart?.blocks.first?.entryID, second.id)
        XCTAssertEqual(JournalPager.pageIndex(of: second.id, in: pages), secondStart?.index)
    }

    func testPhotosFollowTheLastWordsOfTheirEntry() {
        let pager = JournalPager(charactersPerLine: 30, linesPerPage: 20)
        let entry = item("Found a strange stone.", photos: true)
        let blocks = pager.pages(for: [entry]).flatMap(\.blocks)
        XCTAssertEqual(blocks.last?.showsPhotos, true)
        XCTAssertEqual(blocks.filter(\.showsPhotos).count, 1)
    }

    func testParagraphBreaksSurvive() {
        let pager = JournalPager(charactersPerLine: 40, linesPerPage: 20)
        let pages = pager.pages(for: [item("First thought.\n\nSecond thought.")])
        XCTAssertEqual(pages[0].blocks[0].text, "First thought.\nSecond thought.")
    }

    func testSizeEstimateGivesSensibleCapacity() {
        let pager = JournalPager(width: 330, height: 560, fontSize: 19)
        XCTAssertEqual(pager.charactersPerLine, 34)
        XCTAssertEqual(pager.linesPerPage, 19)
    }
}
