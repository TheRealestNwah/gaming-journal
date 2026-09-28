import XCTest
import SwiftData
@testable import GamingJournal

final class JourneyCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private var calculator: JourneyCalculator {
        JourneyCalculator(calendar: calendar, now: date(9, 30, 18))
    }

    func testDaysOnJourneyCountsInclusiveCalendarDays() {
        let ongoing = Notebook(title: "A", startedAt: date(9, 28, 23))
        XCTAssertEqual(calculator.daysOnJourney(ongoing), 3)

        let today = Notebook(title: "B", startedAt: date(9, 30, 1))
        XCTAssertEqual(calculator.daysOnJourney(today), 1)

        let finished = Notebook(title: "C", status: .completed, startedAt: date(8, 1))
        finished.updatedAt = date(8, 10)
        XCTAssertEqual(calculator.daysOnJourney(finished), 10)
    }

    @MainActor
    func testSummaryAcrossNotebooks() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let a = Notebook(title: "A", startedAt: date(9, 21))
        let b = Notebook(title: "B", status: .completed, startedAt: date(9, 1))
        b.updatedAt = date(9, 5)
        context.insert(a)
        context.insert(b)
        a.entries = [
            Entry(body: "one two three", isTurningPoint: true),
            Entry(body: "four five"),
        ]
        b.entries = [Entry(body: "six")]
        let session = PlaySession(gameTitle: "A", durationMinutes: 90)
        context.insert(session)
        session.notebook = a
        try context.save()

        let summary = calculator.summary(of: [a, b])
        XCTAssertEqual(summary.notebookCount, 2)
        XCTAssertEqual(summary.completedCount, 1)
        XCTAssertEqual(summary.daysOnJourney, 10)
        XCTAssertEqual(summary.entryCount, 3)
        XCTAssertEqual(summary.wordCount, 6)
        XCTAssertEqual(summary.minutesPlayed, 90)
        XCTAssertEqual(summary.turningPoints, 1)
        XCTAssertEqual(calculator.summary(of: []), JourneyCalculator.Summary())
    }

    func testEmotionGroupsWeighByIntensity() {
        let entries = [
            Entry(emotions: [FeltEmotion(.grieving, intensity: 3), FeltEmotion(.hopeful, intensity: 1)]),
            Entry(emotions: [FeltEmotion(.afraid, intensity: 2), FeltEmotion(.proud, intensity: 1)]),
        ]
        let groups = calculator.emotionGroups(in: entries)
        XCTAssertEqual(groups.map(\.group), [.shadow, .resolve])
        XCTAssertEqual(groups.map(\.weight), [5, 2])
    }

    func testEntriesPerMonthFillsGapsUpToNow() {
        let entries = [
            Entry(writtenAt: date(6, 15)),
            Entry(writtenAt: date(6, 20)),
            Entry(writtenAt: date(8, 2)),
        ]
        let months = calculator.entriesPerMonth(entries)
        XCTAssertEqual(months.map(\.entries), [2, 0, 1, 0])
        XCTAssertEqual(months.first?.month, date(6, 1, 0))
        XCTAssertEqual(months.last?.month, date(9, 1, 0))
        XCTAssertTrue(calculator.entriesPerMonth([]).isEmpty)
    }
}
