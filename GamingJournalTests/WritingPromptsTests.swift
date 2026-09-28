import XCTest
@testable import GamingJournal

final class WritingPromptsTests: XCTestCase {
    func testFillSkipsTemplatesWithMissingValues() {
        let bare = WritingPrompts.Context(name: "Karlach")
        XCTAssertEqual(WritingPrompts.fill("What does {name} fear most tonight?", with: bare),
                       "What does Karlach fear most tonight?")
        XCTAssertNil(WritingPrompts.fill("What does {name} really think of {other}?", with: bare))
        XCTAssertNil(WritingPrompts.fill("What does {place} smell like to {name}?", with: bare))

        let rich = WritingPrompts.Context(name: "Karlach", bondNames: ["Wyll"], place: "Baldur's Gate", quest: "Find a cure")
        XCTAssertEqual(WritingPrompts.fill("What does {name} really think of {other}?", with: rich),
                       "What does Karlach really think of Wyll?")
        XCTAssertEqual(WritingPrompts.fill("{quest} weighs on {name}.", with: rich), "Find a cure weighs on Karlach.")
    }

    func testNarratorPromptsAddressTheParty() {
        let prompt = WritingPrompts.fill("What does {name} dream about?", with: WritingPrompts.Context())
        XCTAssertEqual(prompt, "What does the party dream about?")
    }

    func testCandidatesFavourRecentFeelingsAndIncludeContext() {
        let context = WritingPrompts.Context(name: "Tav", recentEmotions: [.grieving, .afraid], bondNames: ["Astarion"], place: "Moonrise Towers")
        let candidates = WritingPrompts.candidates(for: context)

        // Shadow prompts are listed once per matching recent emotion, ahead of everything else.
        let shadow = WritingPrompts.byGroup[.shadow]!.compactMap { WritingPrompts.fill($0, with: context) }
        XCTAssertEqual(Array(candidates.prefix(shadow.count * 2)), shadow + shadow)
        XCTAssertTrue(candidates.contains("What does Tav really think of Astarion?"))
        XCTAssertTrue(candidates.contains("What will Tav remember about Moonrise Towers years from now?"))
        XCTAssertFalse(candidates.contains { $0.contains("{") })
    }

    func testSeedWalksThroughCandidatesAndWraps() {
        let context = WritingPrompts.Context(name: "Tav")
        let candidates = WritingPrompts.candidates(for: context)
        XCTAssertEqual(WritingPrompts.prompt(for: context, seed: 0), candidates[0])
        XCTAssertEqual(WritingPrompts.prompt(for: context, seed: 1), candidates[1])
        XCTAssertEqual(WritingPrompts.prompt(for: context, seed: candidates.count), candidates[0])
        XCTAssertEqual(WritingPrompts.prompt(for: context, seed: -1), candidates.last)
    }

    @MainActor
    func testContextComesFromTheWritersRecentEntries() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let notebook = Notebook(title: "Tav's Road")
        let tav = PartyMember(name: "Tav")
        container.mainContext.insert(notebook)
        notebook.members = [tav]
        let older = Entry(writtenAt: Date(timeIntervalSince1970: 100), place: "Emerald Grove",
                          emotions: [FeltEmotion(.hopeful, intensity: 1)],
                          bonds: [Bond(targetName: "Shadowheart", affinity: 1)])
        let newer = Entry(writtenAt: Date(timeIntervalSince1970: 200), quest: "Rescue the tieflings",
                          emotions: [FeltEmotion(.angry, intensity: 1), FeltEmotion(.afraid, intensity: 3)],
                          bonds: [Bond(targetName: "Minthara", affinity: -3)])
        notebook.entries = [older, newer]
        older.author = tav
        newer.author = tav
        try container.mainContext.save()

        let context = WritingPrompts.context(for: tav, in: notebook)
        XCTAssertEqual(context.name, "Tav")
        XCTAssertEqual(context.recentEmotions, [.afraid, .angry, .hopeful])
        XCTAssertEqual(context.bondNames, ["Minthara", "Shadowheart"])
        XCTAssertEqual(context.place, "Emerald Grove")
        XCTAssertEqual(context.quest, "Rescue the tieflings")
    }
}
