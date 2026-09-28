import XCTest
import SwiftData
@testable import GamingJournal

final class EntryDraftTests: XCTestCase {
    func testValidityNeedsTitleBodyOrFeeling() {
        var draft = EntryDraft()
        XCTAssertFalse(draft.isValid)
        draft.body = "  \n "
        XCTAssertFalse(draft.isValid)
        draft.cycle(.hopeful)
        XCTAssertTrue(draft.isValid)
        draft = EntryDraft()
        draft.title = "Dawn"
        XCTAssertTrue(draft.isValid)
    }

    func testCyclingAnEmotionStrengthensThenClears() {
        var draft = EntryDraft()
        draft.cycle(.afraid)
        XCTAssertEqual(draft.intensity(of: .afraid), 1)
        draft.cycle(.afraid)
        draft.cycle(.afraid)
        XCTAssertEqual(draft.intensity(of: .afraid), 3)
        draft.cycle(.afraid)
        XCTAssertNil(draft.intensity(of: .afraid))
    }

    @MainActor
    func testSaveAndEditRoundTrip() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let notebook = Notebook(title: "Tav's Road")
        let karlach = PartyMember(name: "Karlach")
        context.insert(notebook)
        notebook.members = [karlach]

        var draft = EntryDraft(authorID: karlach.id)
        draft.title = "  Out of   the fire "
        draft.body = "My engine burns hotter every day.\n"
        draft.place = " Emerald  Grove "
        draft.cycle(.weary)
        draft.bonds = [Bond(targetName: "Wyll", affinity: 2), Bond(targetName: "  ", affinity: 1)]
        draft.photos = [DraftPhoto(imageData: Data([1]), thumbnailData: Data([2]))]
        let written = Date(timeIntervalSince1970: 5_000)
        let entry = draft.makeEntry(in: notebook, now: written)
        context.insert(entry)
        entry.notebook = notebook
        try context.save()

        XCTAssertEqual(entry.title, "Out of the fire")
        XCTAssertEqual(entry.body, "My engine burns hotter every day.")
        XCTAssertEqual(entry.place, "Emerald Grove")
        XCTAssertEqual(entry.author?.name, "Karlach")
        XCTAssertEqual(entry.emotions, [FeltEmotion(.weary, intensity: 1)])
        XCTAssertEqual(entry.bonds.map(\.targetName), ["Wyll"])
        XCTAssertEqual(entry.sortedPhotos.count, 1)
        XCTAssertEqual(notebook.updatedAt, written)

        var edit = EntryDraft(entry: entry)
        XCTAssertEqual(edit.authorID, karlach.id)
        XCTAssertEqual(edit.photos.count, 1)
        edit.authorID = nil
        edit.photos = []
        edit.apply(to: entry, in: notebook)
        try context.save()
        XCTAssertNil(entry.author)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<EntryPhoto>()), 0)
    }

    @MainActor
    func testDeleteEntryAndUndo() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let notebook = Notebook(title: "Frostbound")
        let solaire = PartyMember(name: "Solaire")
        let entry = Entry(title: "Praise the sun", emotions: [FeltEmotion(.joyful, intensity: 3)])
        context.insert(notebook)
        notebook.members = [solaire]
        notebook.entries = [entry]
        entry.author = solaire
        try context.save()

        let center = UndoCenter()
        context.deleteEntry(entry, undo: center)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Entry>()), 0)
        XCTAssertEqual(center.toast?.message, "Deleted “Praise the sun”")

        center.undo()
        let restored = try XCTUnwrap(context.fetch(FetchDescriptor<Entry>()).first)
        XCTAssertEqual(restored.notebook?.title, "Frostbound")
        XCTAssertEqual(restored.author?.name, "Solaire")
        XCTAssertEqual(restored.emotions.first?.emotion, .joyful)
    }
}

final class ChronicleFilterTests: XCTestCase {
    private let lydia = PartyMember(name: "Lydia")
    private let serana = PartyMember(name: "Serana")

    private func entries() -> [Entry] {
        let a = Entry(title: "Bleak Falls", body: "Found the dragonstone.", place: "Bleak Falls Barrow",
                      quest: "The Golden Claw", emotions: [FeltEmotion(.determined)])
        a.author = lydia
        let b = Entry(title: "Castle Volkihar", body: "Her family is… complicated.", place: "Castle Volkihar",
                      isTurningPoint: true, emotions: [FeltEmotion(.conflicted), FeltEmotion(.loving)])
        b.author = serana
        let c = Entry(body: "Rain again in Whiterun.", place: " bleak falls  barrow")
        return [a, b, c]
    }

    private func titles(_ filter: ChronicleFilter) -> [String] {
        filter.apply(to: entries()).map { $0.title.isEmpty ? $0.body : $0.title }
    }

    func testSearchMatchesTextPlaceQuestAndAuthor() {
        XCTAssertEqual(titles(ChronicleFilter(searchText: "dragonstone")), ["Bleak Falls"])
        XCTAssertEqual(titles(ChronicleFilter(searchText: "golden claw")), ["Bleak Falls"])
        XCTAssertEqual(titles(ChronicleFilter(searchText: "serana")), ["Castle Volkihar"])
        XCTAssertEqual(titles(ChronicleFilter(searchText: "rain whiterun")), ["Rain again in Whiterun."])
    }

    func testFacets() {
        XCTAssertEqual(titles(ChronicleFilter(memberID: lydia.id)), ["Bleak Falls"])
        XCTAssertEqual(titles(ChronicleFilter(emotion: .loving)), ["Castle Volkihar"])
        XCTAssertEqual(titles(ChronicleFilter(place: "Bleak Falls Barrow")), ["Bleak Falls", "Rain again in Whiterun."])
        XCTAssertEqual(titles(ChronicleFilter(turningPointsOnly: true)), ["Castle Volkihar"])
    }

    func testClearFacetsKeepsSearch() {
        var filter = ChronicleFilter(searchText: "x", memberID: lydia.id, emotion: .lost, place: "Y", turningPointsOnly: true)
        filter.clearFacets()
        XCTAssertFalse(filter.hasFacets)
        XCTAssertTrue(filter.isActive)
    }
}

final class AtlasTests: XCTestCase {
    func testPlacesGroupSpellingsAndTrackWriters() {
        let lydia = PartyMember(name: "Lydia")
        let first = Entry(writtenAt: Date(timeIntervalSince1970: 100), place: "whiterun")
        first.author = lydia
        let second = Entry(writtenAt: Date(timeIntervalSince1970: 300), place: "Whiterun")
        second.author = lydia
        let third = Entry(writtenAt: Date(timeIntervalSince1970: 200), place: "Riverwood", quest: "Before the Storm")
        let places = Atlas.places(in: [first, second, third])

        XCTAssertEqual(places.map(\.name), ["Whiterun", "Riverwood"])
        XCTAssertEqual(places[0].entryCount, 2)
        XCTAssertEqual(places[0].firstSeen, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(places[0].writers, ["Lydia"])
        XCTAssertEqual(Atlas.quests(in: [first, second, third]).map(\.name), ["Before the Storm"])
    }

    func testSuggestionsPreferPrefixThenRecency() {
        let items = Atlas.places(in: [
            Entry(writtenAt: Date(timeIntervalSince1970: 100), place: "Riverwood"),
            Entry(writtenAt: Date(timeIntervalSince1970: 300), place: "Dawnstar"),
            Entry(writtenAt: Date(timeIntervalSince1970: 200), place: "Winterhold"),
        ])
        XCTAssertEqual(Atlas.suggestions(items, for: "w"), ["Winterhold", "Dawnstar", "Riverwood"])
        XCTAssertEqual(Atlas.suggestions(items, for: "riverwood"), [])
        XCTAssertEqual(Atlas.suggestions(items, for: "", limit: 2), ["Dawnstar", "Winterhold"])
    }
}
