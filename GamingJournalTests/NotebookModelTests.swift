import XCTest
import SwiftData
@testable import GamingJournal

final class NotebookModelTests: XCTestCase {
    func testNotebookDefaultsAndTrimming() {
        let notebook = Notebook(title: "  The Dragonborn's Road ", gameTitle: " Skyrim ", platform: "PC ")
        XCTAssertEqual(notebook.title, "The Dragonborn's Road")
        XCTAssertEqual(notebook.gameTitle, "Skyrim")
        XCTAssertEqual(notebook.platform, "PC")
        XCTAssertEqual(notebook.coverStyle, .ember)
        XCTAssertEqual(notebook.status, .ongoing)
        XCTAssertEqual(notebook.updatedAt, notebook.createdAt)
    }

    func testUnknownRawValuesFallBack() {
        let notebook = Notebook(title: "A")
        notebook.coverStyleRaw = "velvet"
        notebook.statusRaw = "paused"
        XCTAssertEqual(notebook.coverStyle, .ember)
        XCTAssertEqual(notebook.status, .ongoing)

        let member = PartyMember(name: "Lydia")
        member.sigilRaw = "plaid"
        XCTAssertEqual(member.sigil, .ember)
    }

    func testEmotionCatalogueHasSixteenInFiveGroups() {
        XCTAssertEqual(Emotion.allCases.count, 16)
        XCTAssertEqual(Set(Emotion.allCases.map(\.group)), Set(EmotionGroup.allCases))
        for group in EmotionGroup.allCases {
            XCTAssertFalse(Emotion.inGroup(group).isEmpty, "\(group) is empty")
        }
    }

    func testFeltEmotionsClampAndDedupe() {
        let normalized = FeltEmotion.normalized([
            FeltEmotion(.hopeful, intensity: 1),
            FeltEmotion(.afraid, intensity: 9),
            FeltEmotion(.hopeful, intensity: 3),
        ])
        XCTAssertEqual(normalized.map(\.emotion), [.hopeful, .afraid])
        XCTAssertEqual(normalized.map(\.intensity), [3, 3])
        XCTAssertEqual(FeltEmotion(.lost, intensity: -4).intensity, 1)
    }

    func testBondsClampAffinityAndDescribeIt() {
        let bond = Bond(targetName: " Serana ", affinity: 7)
        XCTAssertEqual(bond.targetName, "Serana")
        XCTAssertEqual(bond.affinity, 3)
        XCTAssertEqual(bond.affinityLabel, "Devoted")
        XCTAssertEqual(Bond(targetName: "Ulfric", affinity: -9).affinityLabel, "Sworn enemy")
        XCTAssertEqual(Bond(targetName: "Belethor", affinity: 0).affinityLabel, "Neutral")
    }

    func testEntryStoresEmotionsAndBonds() {
        let entry = Entry(
            title: " Night at the Bannered Mare ",
            body: "We drank to Whiterun, and I finally slept.",
            place: " Whiterun ",
            emotions: [FeltEmotion(.atPeace, intensity: 2)],
            bonds: [Bond(targetName: "Lydia", affinity: 2)]
        )
        XCTAssertEqual(entry.title, "Night at the Bannered Mare")
        XCTAssertEqual(entry.place, "Whiterun")
        XCTAssertEqual(entry.emotions.map(\.emotion), [.atPeace])
        XCTAssertEqual(entry.bonds.map(\.targetName), ["Lydia"])
        XCTAssertEqual(entry.wordCount, 8)

        entry.emotions = [FeltEmotion(.grieving, intensity: 3)]
        entry.bonds.append(Bond(targetName: "Nazeem", affinity: -5))
        XCTAssertEqual(entry.emotions.map(\.emotion), [.grieving])
        XCTAssertEqual(entry.bonds.last?.affinity, -3)
    }

    func testEmptyOrCorruptEncodedValuesReadAsEmpty() {
        let entry = Entry()
        XCTAssertEqual(entry.emotions, [])
        entry.emotionsData = Data("not json".utf8)
        XCTAssertEqual(entry.emotions, [])
    }

    @MainActor
    func testRelationshipsAndCascadeDelete() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext

        let notebook = Notebook(title: "Frostbound", gameTitle: "Dark Souls")
        let knight = PartyMember(name: "Solaire", role: "Knight of Astora", sortIndex: 1)
        let witch = PartyMember(name: "Quelana", role: "Pyromancer", sortIndex: 0)
        context.insert(notebook)
        notebook.members = [knight, witch]
        let older = Entry(title: "Praise the sun", writtenAt: Date(timeIntervalSince1970: 100))
        let newer = Entry(title: "The bell tolls", writtenAt: Date(timeIntervalSince1970: 200))
        notebook.entries = [older, newer]
        older.author = knight
        newer.author = knight
        try context.save()

        XCTAssertEqual(notebook.party.map(\.name), ["Quelana", "Solaire"])
        XCTAssertEqual(notebook.chronicle.map(\.title), ["The bell tolls", "Praise the sun"])
        XCTAssertEqual(knight.journal.map(\.title), ["The bell tolls", "Praise the sun"])

        witch.isRetired = true
        XCTAssertEqual(notebook.party.map(\.name), ["Solaire", "Quelana"])

        // Removing a member keeps their entries, just unsigned.
        context.delete(knight)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Entry>()), 2)
        XCTAssertNil(try context.fetch(FetchDescriptor<Entry>()).first?.author)

        // Deleting the notebook takes its party and entries with it.
        context.delete(notebook)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Entry>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PartyMember>()), 0)
    }
}
