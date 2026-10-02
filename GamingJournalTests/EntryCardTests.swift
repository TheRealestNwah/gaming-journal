import XCTest
@testable import GamingJournal

@MainActor
final class EntryCardTests: XCTestCase {
    func testShareCardRendersAt1080PixelsWithTheEntryAndJournal() throws {
        BookFont.register()
        let journal = Journal(characterName: "Eira")
        let entry = Entry(body: "The dragon came.", inGameDate: "Day 1", place: "Helgen")
        let card = EntryCard(entry: entry, journal: journal)
        XCTAssertEqual(card.heading, "Day 1")
        XCTAssertEqual(card.place, "Helgen")
        XCTAssertEqual(card.text, "The dragon came.")
        XCTAssertEqual(card.journalTitle, "The Journal of Eira")
        let image = try XCTUnwrap(card.render())
        #if os(macOS)
        let bitmap = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        XCTAssertEqual(bitmap?.width, 1080)
        XCTAssertGreaterThan(try XCTUnwrap(bitmap?.height), 0)
        #else
        XCTAssertEqual(image.cgImage?.width, 1080)
        XCTAssertGreaterThan(try XCTUnwrap(image.cgImage?.height), 0)
        #endif
    }
}
