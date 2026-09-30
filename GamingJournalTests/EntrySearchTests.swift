import XCTest
@testable import GamingJournal

final class EntrySearchTests: XCTestCase {
    private func journal(_ name: String, entries: [Entry]) -> Journal {
        let journal = Journal(characterName: name)
        journal.entries = entries
        return journal
    }

    func testFindsEveryWordIgnoringCaseAndAccents() {
        let old = Entry(body: "The dragon came down on Helgen.", inGameDate: "16th of Last Seed", writtenAt: Date(timeIntervalSince1970: 1_000))
        let new = Entry(body: "A DRAGON over Whiterun, and the Jarl's café.", writtenAt: Date(timeIntervalSince1970: 2_000))
        let other = Entry(body: "Nothing but snow.", inGameDate: "Day 3")
        let eira = journal("Eira", entries: [old, new])
        let brynja = journal("Brynja", entries: [other])

        let results = EntrySearch.results(for: "dragon", in: [eira, brynja])
        XCTAssertEqual(results.map(\.entryID), [new.id, old.id], "Newest first")
        XCTAssertEqual(results.first?.characterName, "Eira")
        XCTAssertEqual(results.first?.journalID, eira.id)

        XCTAssertEqual(EntrySearch.results(for: "dragon helgen", in: [eira, brynja]).map(\.entryID), [old.id])
        XCTAssertEqual(EntrySearch.results(for: "cafe", in: [eira]).map(\.entryID), [new.id])
        XCTAssertEqual(EntrySearch.results(for: "last seed", in: [eira]).map(\.entryID), [old.id], "Matches the in-game date")
        XCTAssertEqual(EntrySearch.results(for: "day 3", in: [brynja]).first?.snippet, "Nothing but snow.")
        XCTAssertTrue(EntrySearch.results(for: "   ", in: [eira]).isEmpty)
        XCTAssertTrue(EntrySearch.results(for: "giant", in: [eira]).isEmpty)
    }

    func testSnippetShowsTheWordsAroundTheMatch() {
        let body = String(repeating: "snow and ash ", count: 10) + "then the dragonstone lay before me " + String(repeating: "cold stone ", count: 20)
        let snippet = EntrySearch.snippet(of: body, around: ["dragonstone"])
        XCTAssertTrue(snippet.hasPrefix("…"))
        XCTAssertTrue(snippet.hasSuffix("…"))
        XCTAssertTrue(snippet.contains("dragonstone"))
        XCTAssertLessThanOrEqual(snippet.count, 115)
        // Starts on a whole word.
        let firstWord = snippet.dropFirst().split(separator: " ").first.map(String.init)
        XCTAssertTrue(["snow", "and", "ash", "then"].contains(firstWord ?? ""))
    }

    func testSnippetOfAShortBodyIsTheWholeBody() {
        XCTAssertEqual(EntrySearch.snippet(of: "The dragon\ncame.", around: ["dragon"]), "The dragon came.")
    }

    func testOpeningTrimsAtAWord() {
        let opening = EntrySearch.opening(of: String(repeating: "word ", count: 40), length: 22)
        XCTAssertEqual(opening, "word word word word…")
        XCTAssertEqual(EntrySearch.opening(of: "Short."), "Short.")
    }
}
