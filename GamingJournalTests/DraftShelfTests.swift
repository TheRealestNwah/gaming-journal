import XCTest
@testable import GamingJournal

final class DraftShelfTests: XCTestCase {
    private let suite = "DraftShelfTests"
    private var defaults: UserDefaults!
    private var shelf: DraftShelf!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        shelf = DraftShelf(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func sampleDraft() -> EntryDraft {
        var draft = EntryDraft(authorID: UUID(), chapterID: UUID())
        draft.title = "Out of the fire"
        draft.body = "My engine burns."
        draft.writtenAt = Date(timeIntervalSince1970: 1_000)
        draft.inGameDate = "Tenday 3"
        draft.place = "Emerald Grove"
        draft.quest = "Find a cure"
        draft.isTurningPoint = true
        draft.emotions = [FeltEmotion(.determined, intensity: 2)]
        draft.bonds = [Bond(targetName: "Wyll", affinity: 2, note: "Blade")]
        return draft
    }

    func testKeepsAndRestoresEverythingButPhotos() throws {
        let notebookID = UUID()
        var draft = sampleDraft()
        draft.photos = [DraftPhoto(id: UUID(), imageData: Data([1]), thumbnailData: Data([1]))]
        shelf.keep(draft, for: notebookID, now: Date(timeIntervalSince1970: 5_000))

        let saved = try XCTUnwrap(shelf.saved(for: notebookID))
        XCTAssertEqual(saved.savedAt, Date(timeIntervalSince1970: 5_000))
        var expected = draft
        expected.photos = []
        XCTAssertEqual(saved.draft, expected)
    }

    func testDraftsAreKeptPerNotebook() {
        let first = UUID()
        let second = UUID()
        shelf.keep(sampleDraft(), for: first)
        XCTAssertNotNil(shelf.saved(for: first))
        XCTAssertNil(shelf.saved(for: second))
        shelf.discard(for: first)
        XCTAssertNil(shelf.saved(for: first))
    }

    func testNothingWorthKeepingClearsTheShelf() {
        let notebookID = UUID()
        shelf.keep(sampleDraft(), for: notebookID)
        shelf.keep(EntryDraft(), for: notebookID)
        XCTAssertNil(shelf.saved(for: notebookID))
    }

    func testPreviewPrefersTheTitleAndShortensLongText() {
        XCTAssertEqual(DraftShelf.Saved(sampleDraft()).preview, "Out of the fire")
        var untitled = EntryDraft()
        untitled.body = String(repeating: "ember ", count: 30)
        let preview = DraftShelf.Saved(untitled).preview
        XCTAssertTrue(preview.hasSuffix("…"))
        XCTAssertEqual(preview.count, 61)
    }
}
