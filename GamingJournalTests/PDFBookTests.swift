import PDFKit
#if os(macOS)
import AppKit
#endif
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

    func testBookCanBeTypesetOffTheMainThread() async throws {
        let journal = makeJournal()
        journal.story.first?.place = "Helgen"
        let book = PDFBook.Book(journal, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(book.entries.map(\.heading).first, "16th of Last Seed, 4E 201")
        XCTAssertEqual(book.entries.first?.place, "Helgen")
        let data = await Task.detached { PDFBook.render(book) }.value
        let pdf = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(pdf.pageCount, 2)
        XCTAssertTrue(try XCTUnwrap(pdf.page(at: 1)?.string).contains("Helgen"))
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

    private func jpeg(width: CGFloat, height: CGFloat) -> Data {
        #if os(macOS)
        let image = NSImage(size: CGSize(width: width, height: height), flipped: false) { _ in
            for x in stride(from: 0, to: width, by: 8) {
                NSColor(calibratedHue: x / width, saturation: 0.6, brightness: 0.7, alpha: 1).setFill()
                NSRect(x: x, y: 0, width: 8, height: height).fill()
            }
            return true
        }
        return PhotoProcessor.jpeg(image, maxDimension: max(width, height), quality: 0.8)!
        #else
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            // Stripes, so the picture doesn't compress to nothing.
            for x in stride(from: 0, to: width, by: 8) {
                UIColor(hue: x / width, saturation: 0.6, brightness: 0.7, alpha: 1).setFill()
                context.fill(CGRect(x: x, y: 0, width: 8, height: height))
            }
        }.jpegData(compressionQuality: 0.8)!
        #endif
    }

    func testPicturesArePrintedAfterTheWords() throws {
        let plain = makeJournal()
        let illustrated = makeJournal()
        let entry = try XCTUnwrap(illustrated.story.first)
        entry.photos = [EntryPhoto(imageData: jpeg(width: 2048, height: 1024), thumbnailData: nil)]
        // An entry that's only a picture still gets its date.
        let pictureOnly = Entry(body: "", inGameDate: "Day 9", writtenAt: Date(timeIntervalSince1970: 3_000_000))
        pictureOnly.photos = [EntryPhoto(imageData: nil, thumbnailData: jpeg(width: 200, height: 300))]
        illustrated.entries?.append(pictureOnly)

        let data = PDFBook.render(illustrated, locale: Locale(identifier: "en_US"))
        XCTAssertGreaterThan(data.count, PDFBook.render(plain, locale: Locale(identifier: "en_US")).count)
        let pdf = try XCTUnwrap(PDFDocument(data: data))
        let text = (1..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
        XCTAssertTrue(text.contains("The dragon came."))
        XCTAssertTrue(text.contains("Riverwood."))
        XCTAssertTrue(text.contains("Day 9"))
    }

    func testPictureSizeFitsThePageWithoutEnlarging() {
        let box = PDFBook.textBox
        let wide = PDFBook.pictureSize(for: CGSize(width: 2048, height: 1024))
        XCTAssertEqual(wide.width, box.width)
        XCTAssertLessThanOrEqual(wide.height, PDFBook.maxPictureHeight)
        let tall = PDFBook.pictureSize(for: CGSize(width: 1000, height: 3000))
        XCTAssertEqual(tall.height, PDFBook.maxPictureHeight)
        XCTAssertLessThan(tall.width, box.width)
        XCTAssertEqual(PDFBook.pictureSize(for: CGSize(width: 80, height: 60)), CGSize(width: 80, height: 60))
        XCTAssertEqual(PDFBook.pictureSize(for: .zero), .zero)
    }

    func testTitleAndFilename() throws {
        let journal = makeJournal()
        let pdf = try document(journal)
        XCTAssertEqual(pdf.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String, "The Journal of Eira Stormborn")
        XCTAssertEqual(PDFBook.filename(for: journal), "The Journal of Eira Stormborn")
    }
}
