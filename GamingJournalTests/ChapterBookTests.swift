import XCTest
import SwiftData
@testable import GamingJournal

final class ChapterBookTests: XCTestCase {
    /// A notebook with two acts (the grove, then the Underdark) and one entry outside them.
    private func makeBook() -> (Notebook, grove: Chapter, underdark: Chapter, entries: [String: Entry]) {
        let notebook = Notebook(title: "Tav's Road")
        let grove = Chapter(title: "Act I: The Grove", sortIndex: 0)
        let underdark = Chapter(title: "Act II: The Underdark", summary: "Down among the myconids.", sortIndex: 1)
        let arrival = Entry(title: "The grove", writtenAt: Date(timeIntervalSince1970: 1_000))
        let goblins = Entry(title: "Goblin camp", writtenAt: Date(timeIntervalSince1970: 2_000))
        let descent = Entry(title: "Descent", writtenAt: Date(timeIntervalSince1970: 3_000))
        let aside = Entry(title: "A quiet night", writtenAt: Date(timeIntervalSince1970: 2_500))
        notebook.chapters = [underdark, grove]
        notebook.entries = [arrival, goblins, descent, aside]
        arrival.chapter = grove
        goblins.chapter = grove
        descent.chapter = underdark
        let byTitle = Dictionary(uniqueKeysWithValues: [arrival, goblins, descent, aside].map { ($0.title, $0) })
        return (notebook, grove, underdark, byTitle)
    }

    func testPartsPutTheLatestChapterFirstAndLoosePagesLast() {
        let (notebook, _, _, _) = makeBook()
        let parts = ChapterBook.parts(notebook.chronicle, chapters: notebook.orderedChapters, includeEmpty: true)
        XCTAssertEqual(parts.map { $0.chapter?.title }, ["Act II: The Underdark", "Act I: The Grove", nil])
        XCTAssertEqual(parts.map { $0.entries.map(\.title) }, [["Descent"], ["Goblin camp", "The grove"], ["A quiet night"]])
    }

    func testWithoutChaptersTheChronicleIsOnePart() {
        let notebook = Notebook(title: "Frostbound")
        notebook.entries = [Entry(title: "One"), Entry(title: "Two")]
        let parts = ChapterBook.parts(notebook.chronicle, chapters: [], includeEmpty: true)
        XCTAssertEqual(parts.count, 1)
        XCTAssertNil(parts.first?.chapter)
        XCTAssertTrue(ChapterBook.parts([], chapters: [], includeEmpty: true).isEmpty)
    }

    func testEmptyChaptersShowOnlyWhenAsked() {
        let (notebook, _, _, _) = makeBook()
        let finale = Chapter(title: "Act III", sortIndex: 2)
        notebook.chapters?.append(finale)
        let everything = ChapterBook.parts(notebook.chronicle, chapters: notebook.orderedChapters, includeEmpty: true)
        XCTAssertEqual(everything.first?.chapter?.title, "Act III")
        XCTAssertEqual(everything.first?.entries.count, 0)
        let filtered = ChapterBook.parts(notebook.chronicle, chapters: notebook.orderedChapters, includeEmpty: false)
        XCTAssertFalse(filtered.contains { $0.chapter?.id == finale.id })
    }

    func testNewChaptersGoLastAndNewEntriesStartThere() {
        let (notebook, _, underdark, _) = makeBook()
        XCTAssertEqual(ChapterBook.nextSortIndex(in: notebook), 2)
        XCTAssertEqual(ChapterBook.nextSortIndex(in: Notebook(title: "Empty")), 0)
        XCTAssertEqual(ChapterBook.current(in: notebook)?.id, underdark.id)
        XCTAssertEqual(EntryDraft.new(in: notebook).chapterID, underdark.id)
        XCTAssertNil(EntryDraft.new(in: Notebook(title: "Empty")).chapterID)
    }

    func testMoveRenumbersInTheNewOrder() {
        let chapters = (0..<4).map { Chapter(title: "Act \($0 + 1)", sortIndex: $0) }
        ChapterBook.move(chapters, from: [3], to: 0)
        XCTAssertEqual(chapters.sorted { $0.sortIndex < $1.sortIndex }.map(\.title), ["Act 4", "Act 1", "Act 2", "Act 3"])
        let again = chapters.sorted { $0.sortIndex < $1.sortIndex }
        ChapterBook.move(again, from: [0], to: 4)
        XCTAssertEqual(again.sorted { $0.sortIndex < $1.sortIndex }.map(\.title), ["Act 1", "Act 2", "Act 3", "Act 4"])
    }

    func testTidyTitlesNamesBlankChapters() {
        let blank = Chapter(title: "Placeholder")
        blank.title = "   "
        let messy = Chapter(title: "Placeholder")
        messy.title = "  Act   II "
        messy.summary = " Down we go.\n"
        ChapterBook.tidyTitles(of: [blank, messy])
        XCTAssertEqual(blank.title, ChapterBook.untitled)
        XCTAssertEqual(messy.title, "Act II")
        XCTAssertEqual(messy.summary, "Down we go.")
    }

    func testFilterByChapter() {
        let (notebook, grove, _, _) = makeBook()
        var filter = ChronicleFilter()
        filter.chapterID = grove.id
        XCTAssertTrue(filter.hasFacets)
        XCTAssertEqual(filter.apply(to: notebook.chronicle).map(\.title), ["Goblin camp", "The grove"])
        filter.clearFacets()
        XCTAssertNil(filter.chapterID)
    }

    func testDraftKeepsAndAppliesTheChapter() throws {
        let (notebook, grove, underdark, entries) = makeBook()
        let descent = try XCTUnwrap(entries["Descent"])
        var draft = EntryDraft(entry: descent)
        XCTAssertEqual(draft.chapterID, underdark.id)
        draft.chapterID = grove.id
        draft.apply(to: descent, in: notebook)
        XCTAssertEqual(descent.chapter?.id, grove.id)
        draft.chapterID = nil
        draft.apply(to: descent, in: notebook)
        XCTAssertNil(descent.chapter)
    }

    func testMarkdownBookUsesChaptersAsSections() throws {
        let (notebook, _, _, _) = makeBook()
        let markdown = NotebookMarkdown.render(notebook, locale: Locale(identifier: "en_US"))
        XCTAssertFalse(markdown.contains("## Chronicle"))
        let grove = try XCTUnwrap(markdown.range(of: "## Act I: The Grove"))
        let underdark = try XCTUnwrap(markdown.range(of: "## Act II: The Underdark"))
        let loose = try XCTUnwrap(markdown.range(of: "## Loose pages"))
        XCTAssertLessThan(grove.lowerBound, underdark.lowerBound)
        XCTAssertLessThan(underdark.lowerBound, loose.lowerBound)
        XCTAssertTrue(markdown.contains("## Act II: The Underdark\n\n*Down among the myconids.*"))
        // Story order inside a chapter.
        let camp = try XCTUnwrap(markdown.range(of: "### Goblin camp"))
        let arrival = try XCTUnwrap(markdown.range(of: "### The grove"))
        XCTAssertLessThan(arrival.lowerBound, camp.lowerBound)
        XCTAssertGreaterThan(markdown.range(of: "### A quiet night")!.lowerBound, loose.lowerBound)
    }

    @MainActor
    func testUndoingADeletePutsTheEntryBackInItsChapter() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let notebook = Notebook(title: "Tav's Road")
        let underdark = Chapter(title: "Act II")
        let descent = Entry(title: "Descent")
        context.insert(notebook)
        context.insert(underdark)
        context.insert(descent)
        underdark.notebook = notebook
        descent.notebook = notebook
        descent.chapter = underdark
        try context.save()

        let snapshot = EntrySnapshot(descent)
        context.delete(descent)
        try context.save()
        XCTAssertTrue(underdark.story.isEmpty)

        snapshot.restore(into: context)
        try context.save()
        XCTAssertEqual(underdark.story.map(\.title), ["Descent"])
        withExtendedLifetime(container) {}
    }
}
