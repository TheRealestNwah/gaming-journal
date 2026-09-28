import XCTest
import SwiftData
@testable import GamingJournal

final class NotebookSessionsTests: XCTestCase {
    func testTimerCarriesNotebookIntoTheDraftAndSurvivesEncoding() throws {
        let notebookID = UUID()
        var state = TimerState(gameTitle: "Elden Ring", startedAt: Date(timeIntervalSince1970: 0), notebookID: notebookID)
        state.pause(at: Date(timeIntervalSince1970: 1_800))
        XCTAssertEqual(state.draft(at: .distantFuture).notebookID, notebookID)

        let decoded = try JSONDecoder().decode(TimerState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.notebookID, notebookID)
    }

    func testOlderSavedTimerWithoutNotebookStillDecodes() throws {
        let json = #"{"gameTitle":"Hades","startedAt":0,"accumulated":60}"#
        let state = try JSONDecoder().decode(TimerState.self, from: Data(json.utf8))
        XCTAssertNil(state.notebookID)
        XCTAssertTrue(state.isPaused)
    }

    @MainActor
    func testSessionDraftLinksAndUnlinksNotebook() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let notebook = Notebook(title: "Tarnished", gameTitle: "Elden Ring", createdAt: Date(timeIntervalSince1970: 0))
        context.insert(notebook)

        var draft = SessionDraft()
        draft.gameTitle = "Elden Ring"
        draft.notebookID = notebook.id
        let session = draft.makeSession(index: GameTitleIndex(entries: []))
        context.insert(session)
        draft.linkNotebook(of: session, from: [notebook])
        try context.save()
        XCTAssertEqual(session.notebook?.id, notebook.id)
        XCTAssertEqual(notebook.sessions?.count, 1)
        XCTAssertGreaterThan(notebook.updatedAt, Date(timeIntervalSince1970: 0))

        var edit = SessionDraft(session: session)
        XCTAssertEqual(edit.notebookID, notebook.id)
        edit.notebookID = nil
        edit.linkNotebook(of: session, from: [notebook])
        try context.save()
        XCTAssertNil(session.notebook)
        XCTAssertEqual(notebook.sessions?.count, 0)
    }

    func testEntryAfterSessionIsDatedAndSignedByTheFirstActiveMember() {
        let notebook = Notebook(title: "Tarnished")
        let retired = PartyMember(name: "Blaidd", sortIndex: 0)
        retired.isRetired = true
        let active = PartyMember(name: "Melina", sortIndex: 1)
        notebook.members = [retired, active]
        let start = Date(timeIntervalSince1970: 42)

        let draft = EntryDraft.afterSession(in: notebook, startedAt: start)
        XCTAssertEqual(draft.writtenAt, start)
        XCTAssertEqual(draft.authorID, active.id)
    }
}
