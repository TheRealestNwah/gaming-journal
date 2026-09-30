import PDFKit
import XCTest
@testable import GamingJournal

final class PDFBookTests: XCTestCase {
    private func makeJournal(longBody: Bool = false) -> Journal {
        let journal = Journal(characterName: "Eira Stormborn", epithet: "Nord", gameTitle: "Skyrim")
        let body = longBody ? String(repeating: "The road went on through snow and ash. ", count: 400) : "The dragon came."
        journal.entries = [
            Entry(body: body, inGameDate: "16th of Last Seed, 4E 201", writtenAt: Date(timeIntervalSince1970: 1_000_000)),
            Entry(body: "Riverwood.", writtenAt: Date(timeIntervalSince1970: 2_000_000)),
        ]
        return journal
    }

    private func document(_ journal: Journal) throws -> PDFDocument {
        try XCTUnwrap(PDFDocument(data: PDFBook.render(journal, locale: Locale(identifier: "en_US"))))
    }

    func testBookHasCoverThenDatedEntries() throws {
        let pdf = try document(makeJournal())
        XCTAssertEqual(pdf.pageCount, 2)
        let cover = try XCTUnwrap(pdf.page(at: 0)?.string)
        XCTAssertTrue(cover.contains("Eira Stormborn"))
        XCTAssertTrue(cover.contains("Nord · Skyrim"))
        let pages = try XCTUnwrap(pdf.page(at: 1)?.string)
        XCTAssertTrue(pages.contains("16th of Last Seed, 4E 201"))
        XCTAssertTrue(pages.contains("The dragon came."))
        // Without an in-game date the entry is headed by the day it was written.
        XCTAssertTrue(pages.contains("1970"))
    }

    func testLongJournalsFlowOntoMorePages() throws {
        XCTAssertGreaterThan(try document(makeJournal(longBody: true)).pageCount, 3)
    }

    func testEmptyJournalIsJustACover() throws {
        XCTAssertEqual(try document(Journal(characterName: "Nobody")).pageCount, 1)
    }

    func testTitleAndFilename() throws {
        let journal = makeJournal()
        let pdf = try document(journal)
        XCTAssertEqual(pdf.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String, "The Journal of Eira Stormborn")
        XCTAssertEqual(PDFBook.filename(for: journal), "The Journal of Eira Stormborn")
    }
}
