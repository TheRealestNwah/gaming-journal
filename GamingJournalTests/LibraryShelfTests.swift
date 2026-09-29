import XCTest
@testable import GamingJournal

final class LibraryShelfTests: XCTestCase {
    private func makeShelf() -> [Notebook] {
        func notebook(_ title: String, _ status: NotebookStatus, updated: TimeInterval, started: TimeInterval) -> Notebook {
            let notebook = Notebook(title: title, status: status, startedAt: Date(timeIntervalSince1970: started))
            notebook.updatedAt = Date(timeIntervalSince1970: updated)
            return notebook
        }
        return [
            notebook("Frostbound", .completed, updated: 300, started: 10),
            notebook("ashen one", .ongoing, updated: 100, started: 30),
            notebook("Tav's Road", .ongoing, updated: 200, started: 20),
            notebook("Wasteland", .abandoned, updated: 400, started: 40),
        ]
    }

    func testDefaultIsEverythingByLastWritten() {
        let titles = LibraryShelf().arrange(makeShelf()).map(\.title)
        XCTAssertEqual(titles, ["Wasteland", "Frostbound", "Tav's Road", "ashen one"])
    }

    func testFilterByStatus() {
        let shelf = LibraryShelf(filter: .ongoing)
        XCTAssertEqual(shelf.arrange(makeShelf()).map(\.title), ["Tav's Road", "ashen one"])
        XCTAssertEqual(LibraryShelf(filter: .abandoned).arrange(makeShelf()).map(\.title), ["Wasteland"])
    }

    func testSortByStartOrTitle() {
        XCTAssertEqual(LibraryShelf(sort: .started).arrange(makeShelf()).map(\.title),
                       ["Wasteland", "ashen one", "Tav's Road", "Frostbound"])
        // Case-insensitive, like Finder.
        XCTAssertEqual(LibraryShelf(sort: .title).arrange(makeShelf()).map(\.title),
                       ["ashen one", "Frostbound", "Tav's Road", "Wasteland"])
    }

    func testPinnedComeFirstWhateverTheSort() {
        let notebooks = makeShelf()
        notebooks[1].isPinned = true
        XCTAssertEqual(LibraryShelf().arrange(notebooks).first?.title, "ashen one")
        XCTAssertEqual(LibraryShelf(sort: .title).arrange(notebooks).map(\.title),
                       ["ashen one", "Frostbound", "Tav's Road", "Wasteland"])
        notebooks[3].isPinned = true
        XCTAssertEqual(LibraryShelf(sort: .title).arrange(notebooks).prefix(2).map(\.title), ["ashen one", "Wasteland"])
        // Filters still apply to pinned tales.
        XCTAssertFalse(LibraryShelf(filter: .completed).arrange(notebooks).contains { $0.isPinned })
    }

    func testFilterLabelsMatchStatuses() {
        XCTAssertEqual(LibraryShelf.Filter.completed.label, NotebookStatus.completed.label)
        XCTAssertNil(LibraryShelf.Filter.all.status)
    }
}
