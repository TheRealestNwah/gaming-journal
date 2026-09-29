import PDFKit
import XCTest
@testable import GamingJournal

final class PDFBookTests: XCTestCase {
    private func makeNotebook(chapters: Bool, longBody: Bool = false) -> Notebook {
        let notebook = Notebook(title: "Tav's Road", gameTitle: "Baldur's Gate 3", platform: "PC", summary: "Out of the nautiloid.")
        let karlach = PartyMember(name: "Karlach", role: "Barbarian", backstory: "Escaped Avernus.")
        karlach.portraitData = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        let wyll = PartyMember(name: "Wyll", role: "Warlock", sortIndex: 1)
        notebook.members = [karlach, wyll]
        let body = longBody ? String(repeating: "The road went on through ash and ember. ", count: 400) : "My engine burns."
        let first = Entry(title: "Out of the fire", body: body, writtenAt: Date(timeIntervalSince1970: 1_000),
                          isTurningPoint: true, emotions: [FeltEmotion(.determined, intensity: 2)])
        first.author = karlach
        let second = Entry(title: "Into the dark", body: "Down we go.", writtenAt: Date(timeIntervalSince1970: 2_000))
        notebook.entries = [first, second]
        if chapters {
            let actOne = Chapter(title: "Act I: The Grove", sortIndex: 0)
            let actTwo = Chapter(title: "Act II: The Underdark", summary: "Myconids and worse.", sortIndex: 1)
            notebook.chapters = [actTwo, actOne]
            first.chapter = actOne
            second.chapter = actTwo
        }
        return notebook
    }

    private func document(_ notebook: Notebook) throws -> PDFDocument {
        try XCTUnwrap(PDFDocument(data: PDFBook.render(notebook, locale: Locale(identifier: "en_US"))))
    }

    func testBookHasCoverPartyAndChronicle() throws {
        let pdf = try document(makeNotebook(chapters: false))
        XCTAssertEqual(pdf.pageCount, 3)
        let cover = try XCTUnwrap(pdf.page(at: 0)?.string)
        XCTAssertTrue(cover.contains("Tav's Road"))
        XCTAssertTrue(cover.contains("Baldur's Gate 3 · PC"))
        XCTAssertTrue(cover.contains("Out of the nautiloid."))
        let party = try XCTUnwrap(pdf.page(at: 1)?.string)
        XCTAssertTrue(party.contains("The Party"))
        XCTAssertTrue(party.contains("Karlach"))
        XCTAssertTrue(party.contains("Escaped Avernus."))
        let chronicle = try XCTUnwrap(pdf.page(at: 2)?.string)
        XCTAssertTrue(chronicle.contains("Out of the fire"))
        XCTAssertTrue(chronicle.contains("Feeling: Determined"))
        XCTAssertTrue(chronicle.contains("Into the dark"))
        XCTAssertEqual(pdf.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String, "Tav's Road")
    }

    func testEachChapterStartsANewPage() throws {
        let pdf = try document(makeNotebook(chapters: true))
        XCTAssertEqual(pdf.pageCount, 4)
        XCTAssertTrue(pdf.page(at: 2)?.string?.contains("Act I: The Grove") ?? false)
        XCTAssertTrue(pdf.page(at: 3)?.string?.contains("Act II: The Underdark") ?? false)
        XCTAssertTrue(pdf.page(at: 3)?.string?.contains("Myconids and worse.") ?? false)
    }

    func testLongEntriesFlowOntoMorePages() throws {
        let pdf = try document(makeNotebook(chapters: false, longBody: true))
        XCTAssertGreaterThan(pdf.pageCount, 5)
        // Every page after the cover is numbered.
        XCTAssertTrue(pdf.page(at: 4)?.string?.contains("5") ?? false)
    }

    func testSectionsFollowChaptersWithLoosePagesLast() {
        let notebook = makeNotebook(chapters: true)
        notebook.entries?.append(Entry(title: "Aside", writtenAt: Date(timeIntervalSince1970: 1_500)))
        let sections = PDFBook.sections(of: notebook)
        XCTAssertEqual(sections.map(\.title), ["Act I: The Grove", "Act II: The Underdark", "Loose pages"])
        XCTAssertEqual(sections.last?.entries.map(\.title), ["Aside"])
        XCTAssertTrue(PDFBook.sections(of: Notebook(title: "Empty")).isEmpty)
    }

    func testEmptyNotebookIsJustACover() throws {
        let pdf = try document(Notebook(title: "Unwritten"))
        XCTAssertEqual(pdf.pageCount, 1)
    }
}
