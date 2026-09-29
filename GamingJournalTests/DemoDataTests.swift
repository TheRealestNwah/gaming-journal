import XCTest
import SwiftData
@testable import GamingJournal

final class DemoDataTests: XCTestCase {
    @MainActor
    func testSeedCreatesASampleJournalWithDatedEntries() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        DemoData.seed(into: context)

        let journal = try XCTUnwrap(context.fetch(FetchDescriptor<Journal>()).first)
        XCTAssertEqual(journal.title, "The Journal of Eira Stormborn")
        XCTAssertEqual(journal.subtitle, "Nord · Skyrim")
        XCTAssertEqual(journal.story.map(\.inGameDate), [
            "16th of Last Seed, 4E 201", "17th of Last Seed, 4E 201", "20th of Last Seed, 4E 201",
        ])
        XCTAssertEqual(journal.latestEntry?.inGameDate, "20th of Last Seed, 4E 201")
    }
}
