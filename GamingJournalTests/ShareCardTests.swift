import XCTest
@testable import GamingJournal

final class ShareCardTests: XCTestCase {
    private func makeEntry(body: String = "My engine burns.") -> Entry {
        let notebook = Notebook(title: "Tav's Road")
        let karlach = PartyMember(name: "Karlach", role: "Barbarian")
        notebook.members = [karlach]
        let entry = Entry(
            title: "Out of the fire",
            body: body,
            writtenAt: Date(timeIntervalSince1970: 86_400 * 3),
            inGameDate: "Tenday 3",
            place: "Emerald Grove",
            isTurningPoint: true,
            emotions: [FeltEmotion(.determined, intensity: 2), FeltEmotion(.afraid, intensity: 1)]
        )
        entry.author = karlach
        entry.notebook = notebook
        return entry
    }

    func testContentCarriesTheMoment() {
        let content = ShareCard.content(for: makeEntry(), format: .square, includesText: true, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(content.title, "Out of the fire")
        XCTAssertEqual(content.writer, "Karlach")
        XCTAssertEqual(content.role, "Barbarian")
        XCTAssertEqual(content.notebookTitle, "Tav's Road")
        XCTAssertTrue(content.dateLine.hasPrefix("Tenday 3 · "))
        XCTAssertTrue(content.dateLine.contains("1970"))
        XCTAssertEqual(content.place, "Emerald Grove")
        XCTAssertEqual(content.emotions, [.determined, .afraid])
        XCTAssertTrue(content.isTurningPoint)
        XCTAssertEqual(content.excerpt, "My engine burns.")
    }

    func testTextCanBeLeftOff() {
        let content = ShareCard.content(for: makeEntry(), format: .story, includesText: false)
        XCTAssertNil(content.excerpt)
        XCTAssertNil(ShareCard.content(for: makeEntry(body: "  "), format: .story, includesText: true).excerpt)
    }

    func testUnsignedEntriesAreTheNarrators() {
        let content = ShareCard.content(for: Entry(title: "Alone"), format: .square, includesText: true)
        XCTAssertEqual(content.writer, "Narrator")
        XCTAssertEqual(content.role, "")
    }

    func testExcerptCutsAtAWord() {
        XCTAssertEqual(ShareCard.excerpt("  Short.  ", limit: 50), "Short.")
        let long = "The road north was cold, and the wind carried ash from the burning city behind us."
        let cut = ShareCard.excerpt(long, limit: 30)
        XCTAssertEqual(cut, "The road north was cold, and…")
        XCTAssertLessThanOrEqual(cut.count, 31)
    }

    func testStoryFitsMoreThanSquare() {
        let body = String(repeating: "ember ", count: 200)
        let square = ShareCard.content(for: makeEntry(body: body), format: .square, includesText: true).excerpt ?? ""
        let story = ShareCard.content(for: makeEntry(body: body), format: .story, includesText: true).excerpt ?? ""
        XCTAssertLessThan(square.count, story.count)
        XCTAssertLessThanOrEqual(square.count, ShareCard.Format.square.excerptLimit + 1)
    }

    func testFormatsAreSocialSizes() {
        XCTAssertEqual(ShareCard.Format.square.pixelSize, CGSize(width: 1080, height: 1080))
        XCTAssertEqual(ShareCard.Format.story.pixelSize, CGSize(width: 1080, height: 1920))
    }

    func testFilenameFallsBackAndDropsUnsafeCharacters() {
        XCTAssertEqual(ShareCard.filename(for: Entry(title: "Act 1/2: Fire?")), "Act 12 Fire")
        let untitled = makeEntry()
        untitled.title = ""
        XCTAssertEqual(ShareCard.filename(for: untitled), "Tav's Road")
        XCTAssertEqual(ShareCard.filename(for: Entry()), "Entry")
    }
}
