import XCTest
import SwiftData
@testable import GamingJournal

/// The place line under an entry's date (#147): the V1 → V2 migration and everywhere it travels.
@MainActor
final class PlaceTests: XCTestCase {
    func testV1StoreOpensWithEmptyPlaces() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("place-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let entryID = UUID()
        do {
            let v1 = try ModelContainer(
                for: Schema(versionedSchema: HearthboundSchemaV1.self),
                configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(v1)
            let journal = HearthboundSchemaV1.Journal(characterName: "Eira")
            context.insert(journal)
            let entry = HearthboundSchemaV1.Entry(id: entryID, body: "Helgen burned.", inGameDate: "16th of Last Seed")
            context.insert(entry)
            entry.journal = journal
            try context.save()
        }

        let context = ModelContext(try Persistence.makeContainer(url: url))
        let entry = try XCTUnwrap(try context.fetch(FetchDescriptor<Entry>()).first)
        XCTAssertEqual(entry.id, entryID)
        XCTAssertEqual(entry.body, "Helgen burned.")
        XCTAssertEqual(entry.place, "")
        XCTAssertEqual(entry.journal?.characterName, "Eira")
    }

    func testHeadingWithPlace() {
        XCTAssertEqual(Entry(inGameDate: "17th of Last Seed", place: " Whiterun ").headingWithPlace(), "17th of Last Seed · Whiterun")
        XCTAssertEqual(Entry(inGameDate: "17th of Last Seed").headingWithPlace(), "17th of Last Seed")
    }

    func testNewPageStartsWhereTheLastEntryWas() throws {
        let context = ModelContext(try Persistence.makeContainer(inMemory: true))
        let journal = Journal(characterName: "Eira")
        context.insert(journal)
        let entry = Entry(body: "a", inGameDate: "Day 1", place: "Riverwood")
        context.insert(entry)
        entry.journal = journal
        XCTAssertEqual(EntryDraft.new(in: journal).place, "Riverwood")

        var draft = EntryDraft(entry: entry)
        draft.place = "  Bleak   Falls Barrow "
        draft.apply(to: entry, in: journal)
        XCTAssertEqual(entry.place, "Bleak Falls Barrow")
    }

    func testUnfinishedPageKeepsItsPlace() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "PlaceTests"))
        defaults.removePersistentDomain(forName: "PlaceTests")
        let shelf = DraftShelf(defaults: defaults)
        let id = UUID()
        shelf.keep(EntryDraft(body: "Half a thought", place: "Whiterun"), for: id)
        XCTAssertEqual(shelf.saved(for: id)?.draft.place, "Whiterun")

        // A page kept before places existed still reads.
        let old = Data(#"{"body":"Old","inGameDate":"","writtenAt":0,"savedAt":0}"#.utf8)
        let saved = try JSONDecoder().decode(DraftShelf.Saved.self, from: old)
        XCTAssertEqual(saved.draft.place, "")
    }

    func testSearchAndExportsCarryThePlace() throws {
        let context = ModelContext(try Persistence.makeContainer(inMemory: true))
        let journal = Journal(characterName: "Eira")
        context.insert(journal)
        let entry = Entry(body: "The Jarl listened.", inGameDate: "18th of Last Seed", place: "Dragonsreach")
        context.insert(entry)
        entry.journal = journal

        let results = EntrySearch.results(for: "dragonsreach", in: [journal])
        XCTAssertEqual(results.map(\.entryID), [entry.id])
        XCTAssertEqual(results.first?.heading, "18th of Last Seed · Dragonsreach")

        XCTAssertTrue(JournalMarkdown.render(journal).contains("## 18th of Last Seed\n*Dragonsreach*\n\nThe Jarl listened."))
        XCTAssertEqual(WidgetSnapshot.LatestEntry(entry: entry).place, "Dragonsreach")

        let backup = try JournalBackup.decode(JournalBackup(exporting: [journal]).encoded())
        XCTAssertEqual(backup.journals.first?.entries.first?.place, "Dragonsreach")
        XCTAssertEqual(backup.journals.first?.entries.first?.makeEntry().place, "Dragonsreach")
    }

    func testBackupWithoutPlacesStillImports() throws {
        let json = """
        {"version": 3, "exportedAt": "2026-01-01T00:00:00Z", "journals": [{
            "id": "\(UUID().uuidString)", "characterName": "Eira", "epithet": "", "gameTitle": "",
            "coverStyle": "ember", "createdAt": "2026-01-01T00:00:00Z", "updatedAt": "2026-01-01T00:00:00Z",
            "entries": [{"id": "\(UUID().uuidString)", "body": "Old words.", "inGameDate": "",
                "writtenAt": "2026-01-01T00:00:00Z", "createdAt": "2026-01-01T00:00:00Z",
                "updatedAt": "2026-01-01T00:00:00Z", "photos": []}]
        }]}
        """
        let backup = try JournalBackup.decode(Data(json.utf8))
        XCTAssertNil(backup.journals.first?.entries.first?.place)
        XCTAssertEqual(backup.journals.first?.entries.first?.makeEntry().place, "")
    }
}
