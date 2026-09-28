import XCTest
import SwiftData
@testable import GamingJournal

final class BackupV2Tests: XCTestCase {
    @MainActor
    private func makeStore() throws -> (ModelContainer, ModelContext) {
        let container = try Persistence.makeContainer(inMemory: true)
        return (container, container.mainContext)
    }

    @MainActor
    private func seed(_ context: ModelContext) throws -> Notebook {
        let notebook = Notebook(title: "Tav's Road", gameTitle: "Baldur's Gate 3", coverStyle: .arcane)
        let karlach = PartyMember(name: "Karlach", role: "Barbarian", sigil: .crimson)
        karlach.portraitData = Data([7])
        let entry = Entry(
            title: "Out of the fire",
            body: "My engine burns.",
            writtenAt: Date(timeIntervalSince1970: 1_000),
            place: "Emerald Grove",
            isTurningPoint: true,
            emotions: [FeltEmotion(.determined, intensity: 3)],
            bonds: [Bond(targetName: "Wyll", affinity: 2, note: "Blade of Frontiers")]
        )
        entry.photos = [EntryPhoto(imageData: Data([1, 2]), thumbnailData: Data([1]))]
        let session = PlaySession(gameTitle: "Baldur's Gate 3", durationMinutes: 150)
        context.insert(notebook)
        context.insert(session)
        notebook.members = [karlach]
        notebook.entries = [entry]
        entry.author = karlach
        session.notebook = notebook
        try context.save()
        return notebook
    }

    @MainActor
    func testRoundTripIntoAFreshStoreKeepsEverything() throws {
        let (_, source) = try makeStore()
        _ = try seed(source)
        let backup = JournalBackup(
            exporting: try source.fetch(FetchDescriptor<PlaySession>()),
            notebooks: try source.fetch(FetchDescriptor<Notebook>())
        )
        XCTAssertEqual(backup.version, 2)
        // Dates are stored to the millisecond, so compare content rather than exact equality.
        let decoded = try JournalBackup.decode(backup.encoded())
        XCTAssertEqual(decoded.notebooks?.first?.entries.first?.bonds, backup.notebooks?.first?.entries.first?.bonds)
        XCTAssertEqual(decoded.sessions.first?.notebookID, backup.notebooks?.first?.id)

        let (_, target) = try makeStore()
        let report = try JournalImporter.importBackup(decoded, into: target)
        XCTAssertEqual(report, .init(notebooksAdded: 1, entriesAdded: 1, sessionsAdded: 1, skipped: 0))

        let notebook = try XCTUnwrap(target.fetch(FetchDescriptor<Notebook>()).first)
        XCTAssertEqual(notebook.coverStyle, .arcane)
        let member = try XCTUnwrap(notebook.party.first)
        XCTAssertEqual(member.sigil, .crimson)
        XCTAssertEqual(member.portraitData, Data([7]))
        let entry = try XCTUnwrap(notebook.chronicle.first)
        XCTAssertEqual(entry.author?.id, member.id)
        XCTAssertEqual(entry.emotions, [FeltEmotion(.determined, intensity: 3)])
        XCTAssertEqual(entry.bonds.first?.note, "Blade of Frontiers")
        XCTAssertEqual(entry.sortedPhotos.compactMap(\.imageData), [Data([1, 2])])
        XCTAssertTrue(entry.isTurningPoint)
        XCTAssertEqual(notebook.sessions?.first?.durationMinutes, 150)
    }

    @MainActor
    func testReimportAddsOnlyWhatIsNew() throws {
        let (_, context) = try makeStore()
        let notebook = try seed(context)
        let backup = try JournalBackup.decode(JournalBackup(
            exporting: try context.fetch(FetchDescriptor<PlaySession>()),
            notebooks: [notebook]
        ).encoded())

        let again = try JournalImporter.importBackup(backup, into: context)
        XCTAssertEqual(again.notebooksAdded + again.entriesAdded + again.sessionsAdded, 0)
        XCTAssertEqual(again.skipped, 3) // notebook, entry, session
        XCTAssertEqual(again.summary, "Nothing new to add. Skipped 3 already in your journal.")

        // A new entry written elsewhere joins the existing notebook, signed by the same member.
        var extended = backup
        var record = try XCTUnwrap(extended.notebooks?.first)
        var newEntry = try XCTUnwrap(record.entries.first)
        newEntry.id = UUID()
        newEntry.title = "Avernus calls"
        record.entries.append(newEntry)
        extended.notebooks = [record]

        let report = try JournalImporter.importBackup(extended, into: context)
        XCTAssertEqual(report.entriesAdded, 1)
        XCTAssertEqual(notebook.entries?.count, 2)
        XCTAssertEqual(notebook.chronicle.first { $0.title == "Avernus calls" }?.author?.name, "Karlach")
    }

    @MainActor
    func testVersionOneFilesStillImport() throws {
        let json = """
        {"version":1,"exportedAt":"2026-09-28T10:00:00Z","sessions":[{"id":"00000000-0000-0000-0000-000000000009",
        "gameTitle":"Hades","platform":"Switch","startDate":"2026-09-27T20:00:00Z","durationMinutes":45,
        "notes":"","tags":[],"isMilestone":false,"milestoneNote":"","createdAt":"2026-09-27T21:00:00Z","photos":[]}]}
        """
        let backup = try JournalBackup.decode(Data(json.utf8))
        XCTAssertNil(backup.notebooks)
        let (_, context) = try makeStore()
        let report = try JournalImporter.importBackup(backup, into: context)
        XCTAssertEqual(report.sessionsAdded, 1)
        XCTAssertNil(try context.fetch(FetchDescriptor<PlaySession>()).first?.notebook)
    }

    func testReportSummary() {
        let report = JournalImporter.Report(notebooksAdded: 1, entriesAdded: 1, sessionsAdded: 2, skipped: 0)
        XCTAssertEqual(report.summary, "Added 1 notebook, 1 entry, 2 sessions.")
    }
}

final class NotebookMarkdownTests: XCTestCase {
    func testRendersABook() {
        let notebook = Notebook(title: "Frostbound", gameTitle: "Dark Souls", platform: "PS5",
                                startedAt: Date(timeIntervalSince1970: 0), summary: "Bells to ring.")
        let solaire = PartyMember(name: "Solaire", role: "Knight of Astora", backstory: "Seeks his own sun.")
        notebook.members = [solaire]
        let entry = Entry(title: "Praise the sun", body: "We stood together.", writtenAt: Date(timeIntervalSince1970: 86_400),
                          place: "Undead Burg", isTurningPoint: true,
                          emotions: [FeltEmotion(.joyful, intensity: 2)],
                          bonds: [Bond(targetName: "Siegmeyer", affinity: 1)])
        entry.author = solaire
        notebook.entries = [entry]

        let markdown = NotebookMarkdown.render(notebook, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(markdown.hasPrefix("# Frostbound\n*Dark Souls · PS5*"))
        XCTAssertTrue(markdown.contains("> Bells to ring."))
        XCTAssertTrue(markdown.contains("- **Solaire**, Knight of Astora\n  Seeks his own sun."))
        XCTAssertTrue(markdown.contains("### ✦ Praise the sun"))
        XCTAssertTrue(markdown.contains("*Solaire* · "))
        XCTAssertTrue(markdown.contains("Undead Burg"))
        XCTAssertTrue(markdown.contains("Feeling: Joyful••"))
        XCTAssertTrue(markdown.contains("Bonds: Siegmeyer (friendly)"))
        XCTAssertTrue(markdown.hasSuffix("We stood together.\n"))
    }

    func testFilenameDropsUnsafeCharacters() {
        XCTAssertEqual(NotebookMarkdown.filename(for: Notebook(title: "Tav's Road: Act 1/2?")), "Tav's Road Act 12")
        XCTAssertEqual(NotebookMarkdown.filename(for: Notebook(title: "///")), "Notebook")
    }
}

final class WidgetEntryTests: XCTestCase {
    func testWriteURLRoundTripsNotebookID() {
        let id = UUID()
        XCTAssertEqual(WidgetSnapshot.notebookID(inWriteURL: WidgetSnapshot.writeURL(for: id)), id)
        XCTAssertNil(WidgetSnapshot.notebookID(inWriteURL: WidgetSnapshot.writeURL))
        XCTAssertNil(WidgetSnapshot.notebookID(inWriteURL: WidgetSnapshot.startTimerURL))
    }

    func testLatestEntryExcerptIsTrimmed() {
        let notebook = Notebook(title: "Tav's Road")
        let entry = Entry(title: "Long", body: String(repeating: "word ", count: 100))
        entry.notebook = notebook
        let latest = WidgetSnapshot.LatestEntry(entry: entry)
        XCTAssertEqual(latest.author, "Narrator")
        XCTAssertEqual(latest.notebookTitle, "Tav's Road")
        XCTAssertTrue(latest.excerpt.hasSuffix("…"))
        XCTAssertLessThanOrEqual(latest.excerpt.count, WidgetSnapshot.LatestEntry.excerptLength + 1)
    }
}
