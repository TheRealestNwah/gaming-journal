import XCTest
@testable import GamingJournal

final class LibrarySearchTests: XCTestCase {
    private func makeLibrary() -> (tav: Notebook, ashen: Notebook) {
        let tav = Notebook(title: "Tav's Road", gameTitle: "Baldur's Gate 3")
        tav.updatedAt = Date(timeIntervalSince1970: 2_000)
        let karlach = PartyMember(name: "Karlach")
        tav.members = [karlach]
        let fire = Entry(title: "Out of the fire", body: "My engine burns hotter every day.", writtenAt: Date(timeIntervalSince1970: 100))
        fire.author = karlach
        let grove = Entry(title: "The grove", body: "Tieflings and druids, and a fire in the square.", writtenAt: Date(timeIntervalSince1970: 200))
        tav.entries = [fire, grove]

        let ashen = Notebook(title: "Ashen One", gameTitle: "Dark Souls 3", platform: "PS5")
        ashen.updatedAt = Date(timeIntervalSince1970: 3_000)
        ashen.entries = [Entry(title: "Firelink", body: "Linked the first flame.")]
        return (tav, ashen)
    }

    func testBlankQueryFindsNothing() {
        let (tav, ashen) = makeLibrary()
        XCTAssertTrue(LibrarySearch.results(for: "   ", in: [tav, ashen]).isEmpty)
    }

    func testEntriesMatchAcrossNotebooksNewestNotebookFirst() {
        let (tav, ashen) = makeLibrary()
        let results = LibrarySearch.results(for: "fire", in: [tav, ashen])
        XCTAssertEqual(results.map(\.notebook.title), ["Ashen One", "Tav's Road"])
        XCTAssertEqual(results[1].entries.map(\.title), ["The grove", "Out of the fire"])
        XCTAssertFalse(results[1].matchesNotebook)
    }

    func testEveryWordMustMatchAndAuthorsCount() {
        let (tav, ashen) = makeLibrary()
        let results = LibrarySearch.results(for: "karlach engine", in: [tav, ashen])
        XCTAssertEqual(results.map(\.notebook.title), ["Tav's Road"])
        XCTAssertEqual(results.first?.entries.map(\.title), ["Out of the fire"])
    }

    func testNotebookNameGameAndPlatformMatchWithoutEntries() {
        let (tav, ashen) = makeLibrary()
        let results = LibrarySearch.results(for: "dark souls ps5", in: [tav, ashen])
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].matchesNotebook)
        XCTAssertTrue(results[0].entries.isEmpty)
    }

    func testExcerptCentresOnTheMatch() {
        let body = (1...40).map { "word\($0)" }.joined(separator: " ") + " dragon " + (41...80).map { "word\($0)" }.joined(separator: " ")
        let excerpt = LibrarySearch.excerpt(of: body, matching: "Dragon", radius: 30)
        XCTAssertTrue(excerpt.hasPrefix("…"))
        XCTAssertTrue(excerpt.hasSuffix("…"))
        XCTAssertTrue(excerpt.contains("dragon"))
        XCTAssertFalse(excerpt.contains("word1 "))
        // Whole words only at both ends.
        XCTAssertTrue(excerpt.dropFirst().hasPrefix("word"))
        XCTAssertTrue(excerpt.dropLast().last?.isNumber == true)
    }

    func testExcerptWithoutAHitShowsTheOpening() {
        XCTAssertEqual(LibrarySearch.excerpt(of: "Short   and\nsweet.", matching: "absent"), "Short and sweet.")
        XCTAssertEqual(LibrarySearch.excerpt(of: "", matching: "x"), "")
        let long = String(repeating: "ember ", count: 60)
        let opening = LibrarySearch.excerpt(of: long, matching: "absent", radius: 20)
        XCTAssertTrue(opening.hasPrefix("ember"))
        XCTAssertTrue(opening.hasSuffix("…"))
        XCTAssertLessThanOrEqual(opening.count, 41)
    }
}
