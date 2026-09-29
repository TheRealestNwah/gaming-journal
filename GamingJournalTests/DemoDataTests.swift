import XCTest
import SwiftData
@testable import GamingJournal

final class DemoDataTests: XCTestCase {
    @MainActor
    func testSeedCreatesASampleNotebookWithPartyEntriesAndSession() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        DemoData.seed(into: context)

        let notebook = try XCTUnwrap(context.fetch(FetchDescriptor<Notebook>()).first)
        XCTAssertEqual(notebook.title, "The Dragonborn's Road")
        XCTAssertEqual(notebook.party.map(\.name), ["Lydia", "Serana"])
        XCTAssertEqual(notebook.entries?.count, 4)
        XCTAssertEqual(notebook.sessions?.count, 1)

        let lydia = try XCTUnwrap(notebook.party.first)
        XCTAssertEqual(lydia.journal.count, 3)
        let bonds = CharacterArc.bonds(in: lydia.journal)
        XCTAssertEqual(bonds.first?.name, "Serana")
        XCTAssertEqual(bonds.first?.trend, .warming)
        XCTAssertGreaterThan(CharacterArc.points(for: lydia.journal).count, 1)
    }
}
