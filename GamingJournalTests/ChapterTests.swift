import XCTest
import SwiftData
@testable import GamingJournal

final class ChapterTests: XCTestCase {
    /// Held for the whole test: a context whose container has been released traps.
    private var containers: [ModelContainer] = []
    private var storeDirectory: URL?

    override func tearDown() {
        containers = []
        if let storeDirectory {
            try? FileManager.default.removeItem(at: storeDirectory)
        }
        super.tearDown()
    }

    @MainActor
    private func makeContext() throws -> ModelContext {
        let container = try Persistence.makeContainer(inMemory: true)
        containers.append(container)
        return container.mainContext
    }

    // MARK: Model

    func testChapterTrimsTitleAndNotebookOrdersThem() {
        let notebook = Notebook(title: "Tav's Road")
        let second = Chapter(title: " Act II: The Underdark ", sortIndex: 1)
        let first = Chapter(title: "Act I: The Grove", sortIndex: 0)
        notebook.chapters = [second, first]
        XCTAssertEqual(second.title, "Act II: The Underdark")
        XCTAssertEqual(notebook.orderedChapters.map(\.title), ["Act I: The Grove", "Act II: The Underdark"])
        XCTAssertFalse(notebook.isPinned)
    }

    @MainActor
    func testDeletingAChapterKeepsItsEntries() throws {
        let context = try makeContext()
        let notebook = Notebook(title: "Tav's Road")
        let chapter = Chapter(title: "Act I")
        let later = Entry(title: "Later", writtenAt: Date(timeIntervalSince1970: 2_000))
        let earlier = Entry(title: "Earlier", writtenAt: Date(timeIntervalSince1970: 1_000))
        context.insert(notebook)
        notebook.chapters = [chapter]
        notebook.entries = [later, earlier]
        later.chapter = chapter
        earlier.chapter = chapter
        try context.save()
        XCTAssertEqual(chapter.story.map(\.title), ["Earlier", "Later"])

        context.delete(chapter)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<Entry>()).count, 2)
        XCTAssertNil(later.chapter)
        XCTAssertEqual(notebook.entries?.count, 2)
    }

    @MainActor
    func testDeletingANotebookRemovesItsChapters() throws {
        let context = try makeContext()
        let notebook = Notebook(title: "Tav's Road")
        context.insert(notebook)
        notebook.chapters = [Chapter(title: "Act I"), Chapter(title: "Act II", sortIndex: 1)]
        try context.save()

        context.delete(notebook)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<Chapter>()).isEmpty)
    }

    @MainActor
    func testUndoingANotebookDeleteBringsBackChaptersAndPin() throws {
        let context = try makeContext()
        let notebook = Notebook(title: "Tav's Road")
        let actTwo = Chapter(title: "Act II", summary: "Below.", sortIndex: 1)
        let entry = Entry(title: "Descent")
        context.insert(notebook)
        notebook.isPinned = true
        notebook.chapters = [Chapter(title: "Act I"), actTwo]
        notebook.entries = [entry]
        entry.chapter = actTwo
        try context.save()

        let center = UndoCenter()
        context.deleteNotebook(notebook, undo: center)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Chapter>()).isEmpty)
        center.undo()

        let restored = try XCTUnwrap(context.fetch(FetchDescriptor<Notebook>()).first)
        XCTAssertTrue(restored.isPinned)
        XCTAssertEqual(restored.orderedChapters.map(\.title), ["Act I", "Act II"])
        XCTAssertEqual(restored.orderedChapters.last?.summary, "Below.")
        XCTAssertEqual(restored.chronicle.first?.chapter?.title, "Act II")
    }

    // MARK: Migration

    @MainActor
    func testVersionOneStoreOpensWithNotebooksIntact() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storeDirectory = directory
        let url = directory.appendingPathComponent("journal.store")

        // Written by a build that only knew version 1.
        try writeVersionOneStore(at: url)

        let container = try Persistence.makeContainer(url: url)
        containers.append(container)
        let context = container.mainContext
        let notebook = try XCTUnwrap(context.fetch(FetchDescriptor<Notebook>()).first)
        XCTAssertEqual(notebook.title, "Frostbound")
        XCTAssertFalse(notebook.isPinned)
        XCTAssertEqual(notebook.chronicle.map(\.title), ["Praise the sun"])
        XCTAssertNil(notebook.chronicle.first?.chapter)
        XCTAssertTrue(notebook.orderedChapters.isEmpty)

        // The migrated store accepts the new fields.
        let chapter = Chapter(title: "Undead Burg")
        context.insert(chapter)
        chapter.notebook = notebook
        notebook.chronicle.first?.chapter = chapter
        notebook.isPinned = true
        try context.save()
        XCTAssertEqual(notebook.orderedChapters.first?.story.count, 1)
    }

    @MainActor
    private func writeVersionOneStore(at url: URL) throws {
        let schema = Schema(versionedSchema: JournalSchemaV1.self)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        )
        let context = container.mainContext
        let notebook = JournalSchemaV1.Notebook(title: "Frostbound", gameTitle: "Dark Souls")
        let entry = JournalSchemaV1.Entry(title: "Praise the sun")
        context.insert(notebook)
        notebook.entries = [entry]
        try context.save()
    }

    // MARK: Backup

    @MainActor
    func testBackupKeepsChaptersPinningAndEntryPlacement() throws {
        let source = try makeContext()
        let notebook = Notebook(title: "Tav's Road")
        let actOne = Chapter(title: "Act I", summary: "The grove.")
        let actTwo = Chapter(title: "Act II", sortIndex: 1)
        let inAct = Entry(title: "Out of the fire")
        let loose = Entry(title: "A quiet night")
        source.insert(notebook)
        notebook.isPinned = true
        notebook.chapters = [actOne, actTwo]
        notebook.entries = [inAct, loose]
        inAct.chapter = actTwo
        try source.save()

        let backup = try JournalBackup.decode(JournalBackup(exporting: [], notebooks: [notebook]).encoded())
        XCTAssertEqual(backup.notebooks?.first?.chapters?.map(\.title), ["Act I", "Act II"])

        let target = try makeContext()
        let report = try JournalImporter.importBackup(backup, into: target)
        XCTAssertEqual(report.notebooksAdded, 1)
        let restored = try XCTUnwrap(target.fetch(FetchDescriptor<Notebook>()).first)
        XCTAssertTrue(restored.isPinned)
        XCTAssertEqual(restored.orderedChapters.map(\.title), ["Act I", "Act II"])
        XCTAssertEqual(restored.orderedChapters.first?.summary, "The grove.")
        XCTAssertEqual(restored.chronicle.first { $0.title == "Out of the fire" }?.chapter?.id, actTwo.id)
        XCTAssertNil(restored.chronicle.first { $0.title == "A quiet night" }?.chapter)
    }

    @MainActor
    func testReimportAddsNewChaptersToAnExistingNotebook() throws {
        let context = try makeContext()
        let notebook = Notebook(title: "Tav's Road")
        context.insert(notebook)
        notebook.chapters = [Chapter(title: "Act I")]
        try context.save()

        var backup = try JournalBackup.decode(JournalBackup(exporting: [], notebooks: [notebook]).encoded())
        var record = try XCTUnwrap(backup.notebooks?.first)
        let actTwo = JournalBackup.ChapterRecord(id: UUID(), title: "Act II", summary: "", sortIndex: 1, createdAt: .now)
        record.chapters?.append(actTwo)
        var entry = JournalBackup.JournalEntry(entry: Entry(title: "Into the Underdark"))
        entry.chapterID = actTwo.id
        record.entries.append(entry)
        backup.notebooks = [record]

        let report = try JournalImporter.importBackup(backup, into: context)
        XCTAssertEqual(report.entriesAdded, 1)
        XCTAssertEqual(notebook.orderedChapters.map(\.title), ["Act I", "Act II"])
        XCTAssertEqual(notebook.orderedChapters.last?.story.map(\.title), ["Into the Underdark"])
    }

    func testBackupsWrittenBeforeChaptersStillRead() throws {
        let backup = JournalBackup(sessions: [], notebooks: [
            JournalBackup.NotebookRecord(notebook: Notebook(title: "Old"))
        ])
        // Strip the fields added with chapters, as an earlier version 2 build would have written.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: backup.encoded()) as? [String: Any])
        var notebooks = try XCTUnwrap(json["notebooks"] as? [[String: Any]])
        notebooks[0]["chapters"] = nil
        notebooks[0]["isPinned"] = nil
        json["notebooks"] = notebooks

        let decoded = try JournalBackup.decode(JSONSerialization.data(withJSONObject: json))
        let record = try XCTUnwrap(decoded.notebooks?.first)
        XCTAssertNil(record.chapters)
        XCTAssertFalse(record.makeNotebook().isPinned)
    }
}
