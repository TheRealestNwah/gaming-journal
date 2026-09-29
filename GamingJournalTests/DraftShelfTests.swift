import XCTest
import SwiftData
@testable import GamingJournal

final class DraftShelfTests: XCTestCase {
    private let suite = "DraftShelfTests"
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

    func testKeepsWordsPerJournalAndForgetsBlankDrafts() throws {
        let shelf = DraftShelf(defaults: defaults)
        let journalID = UUID()
        let otherID = UUID()
        var draft = EntryDraft(inGameDate: "17th of Last Seed")
        draft.body = "Riverwood at last."
        shelf.keep(draft, for: journalID)

        let saved = try XCTUnwrap(shelf.saved(for: journalID))
        XCTAssertEqual(saved.draft.body, "Riverwood at last.")
        XCTAssertEqual(saved.draft.inGameDate, "17th of Last Seed")
        XCTAssertEqual(saved.preview, "Riverwood at last.")
        XCTAssertNil(shelf.saved(for: otherID))

        draft.body = "   "
        shelf.keep(draft, for: journalID)
        XCTAssertNil(shelf.saved(for: journalID))
    }

    func testPreviewIsTrimmedToOneShortLine() {
        let draft = EntryDraft(body: String(repeating: "word ", count: 30))
        let saved = DraftShelf.Saved(draft)
        XCTAssertTrue(saved.preview.hasSuffix("…"))
        XCTAssertLessThanOrEqual(saved.preview.count, 61)
    }
}

@MainActor
final class EntryDraftTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        ModelContext(try Persistence.makeContainer(inMemory: true))
    }

    func testNewPageStartsFromTheLatestInGameDate() throws {
        let context = try makeContext()
        let journal = Journal(characterName: "Eira")
        context.insert(journal)
        let old = Entry(body: "a", inGameDate: "16th of Last Seed", writtenAt: .now.addingTimeInterval(-100))
        let latest = Entry(body: "b", inGameDate: "17th of Last Seed", writtenAt: .now)
        context.insert(old)
        context.insert(latest)
        old.journal = journal
        latest.journal = journal

        XCTAssertEqual(EntryDraft.new(in: journal).inGameDate, "17th of Last Seed")
        XCTAssertEqual(EntryDraft.new(in: Journal(characterName: "New")).inGameDate, "")
    }

    func testSavingTidiesTextAndTouchesTheJournal() throws {
        let context = try makeContext()
        let journal = Journal(characterName: "Eira", createdAt: .distantPast)
        context.insert(journal)
        var draft = EntryDraft(body: "\n  The dragon came.  \n", inGameDate: " 16th  of Last Seed ")
        draft.photos = [DraftPhoto(imageData: Data([1]), thumbnailData: Data([2]))]
        XCTAssertTrue(draft.isValid)

        let entry = Entry()
        context.insert(entry)
        draft.apply(to: entry, in: journal)

        XCTAssertEqual(entry.body, "The dragon came.")
        XCTAssertEqual(entry.inGameDate, "16th of Last Seed")
        XCTAssertEqual(entry.journal?.id, journal.id)
        XCTAssertEqual(entry.sortedPhotos.count, 1)
        XCTAssertGreaterThan(journal.updatedAt, .distantPast)
        XCTAssertEqual(journal.story.map(\.id), [entry.id])
    }

    func testEditingRemovesDroppedPhotos() throws {
        let context = try makeContext()
        let journal = Journal(characterName: "Eira")
        context.insert(journal)
        var draft = EntryDraft(body: "Pictures")
        draft.photos = [DraftPhoto(imageData: Data([1]), thumbnailData: Data([1])), DraftPhoto(imageData: Data([2]), thumbnailData: Data([2]))]
        let entry = Entry()
        context.insert(entry)
        draft.apply(to: entry, in: journal)

        var edit = EntryDraft(entry: entry)
        XCTAssertEqual(edit.photos.count, 2)
        edit.photos.removeFirst()
        edit.apply(to: entry, in: journal)
        XCTAssertEqual(entry.sortedPhotos.map(\.imageData), [Data([2])])
    }

    func testBlankDraftIsNotWorthSaving() {
        XCTAssertFalse(EntryDraft(body: " \n ").isValid)
        XCTAssertFalse(EntryDraft(inGameDate: "Day 3").isValid)
    }

    func testHeadingFallsBackToTheRealDate() {
        let entry = Entry(body: "x", writtenAt: Date(timeIntervalSince1970: 0))
        XCTAssertFalse(entry.heading(locale: Locale(identifier: "en_US")).isEmpty)
        entry.inGameDate = "Day 1"
        XCTAssertEqual(entry.heading(), "Day 1")
    }
}
