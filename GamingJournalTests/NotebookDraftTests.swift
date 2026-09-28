import XCTest
import SwiftData
@testable import GamingJournal

final class NotebookDraftTests: XCTestCase {
    func testBlankTitleFallsBackToGame() {
        var draft = NotebookDraft()
        XCTAssertFalse(draft.isValid)
        draft.gameTitle = "  Baldur's   Gate 3 "
        XCTAssertTrue(draft.isValid)
        XCTAssertEqual(draft.resolvedTitle, "Baldur's Gate 3")
        draft.title = " Tav's   Road "
        XCTAssertEqual(draft.resolvedTitle, "Tav's Road")
    }

    func testRoundTripThroughNotebook() {
        var draft = NotebookDraft()
        draft.title = "Frostbound"
        draft.gameTitle = "Dark Souls"
        draft.platform = " PS5 "
        draft.coverStyle = .frost
        draft.summary = "  A cursed undead seeks the bells.  "
        let created = Date(timeIntervalSince1970: 1_000)
        let notebook = draft.makeNotebook(now: created)

        XCTAssertEqual(notebook.title, "Frostbound")
        XCTAssertEqual(notebook.platform, "PS5")
        XCTAssertEqual(notebook.coverStyle, .frost)
        XCTAssertEqual(notebook.summary, "A cursed undead seeks the bells.")
        XCTAssertEqual(notebook.updatedAt, created)

        var edit = NotebookDraft(notebook: notebook)
        XCTAssertEqual(edit.coverStyle, .frost)
        edit.status = .completed
        edit.apply(to: notebook, now: Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(notebook.status, .completed)
        XCTAssertEqual(notebook.updatedAt, Date(timeIntervalSince1970: 2_000))
    }

    @MainActor
    func testDeleteAndUndoRestoresPartyEntriesAndSessions() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext

        let notebook = Notebook(title: "Tav's Road", gameTitle: "Baldur's Gate 3", coverStyle: .arcane)
        let tav = PartyMember(name: "Tav", role: "Bard")
        let entry = Entry(title: "The nautiloid", emotions: [FeltEmotion(.afraid, intensity: 3)])
        entry.photos = [EntryPhoto(imageData: Data([1]), thumbnailData: nil)]
        let session = PlaySession(gameTitle: "Baldur's Gate 3", durationMinutes: 120)
        context.insert(notebook)
        context.insert(session)
        notebook.members = [tav]
        notebook.entries = [entry]
        entry.author = tav
        session.notebook = notebook
        try context.save()

        let center = UndoCenter()
        context.deleteNotebook(notebook, undo: center)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Notebook>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Entry>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlaySession>()), 1, "sessions outlive their notebook")
        XCTAssertEqual(center.toast?.message, "Deleted Tav's Road")

        center.undo()
        let restored = try XCTUnwrap(context.fetch(FetchDescriptor<Notebook>()).first)
        XCTAssertEqual(restored.coverStyle, .arcane)
        XCTAssertEqual(restored.party.map(\.name), ["Tav"])
        let restoredEntry = try XCTUnwrap(restored.chronicle.first)
        XCTAssertEqual(restoredEntry.author?.name, "Tav")
        XCTAssertEqual(restoredEntry.emotions.map(\.emotion), [.afraid])
        XCTAssertEqual(restoredEntry.sortedPhotos.compactMap(\.imageData), [Data([1])])
        XCTAssertEqual(restored.sessions?.count, 1)
    }
}
