import XCTest
@testable import GamingJournal

final class StatsCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2 // Monday
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// Wednesday 30 September 2026, 18:00 UTC.
    private var now: Date { date(2026, 9, 30, 18) }

    private var calculator: StatsCalculator {
        StatsCalculator(calendar: calendar, now: now)
    }

    private func record(
        _ title: String,
        _ day: Date,
        _ minutes: Int,
        platform: String = "",
        enjoyment: Int? = nil
    ) -> StatsRecord {
        StatsRecord(title: title, platform: platform, start: day, minutes: minutes, enjoyment: enjoyment)
    }

    func testRangeFilteringIncludesTodayAndExcludesFuture() {
        let records = [
            record("A", date(2026, 9, 24, 0), 10),  // first moment of 7D
            record("B", date(2026, 9, 23, 23), 10), // just outside 7D
            record("C", date(2026, 9, 30, 17), 10),
            record("D", date(2026, 9, 30, 19), 10), // later today, after now
            record("E", date(2025, 9, 30, 12), 10), // inside 1Y
            record("F", date(2025, 9, 29, 12), 10), // outside 1Y
        ]
        XCTAssertEqual(calculator.records(records, in: .week).map(\.title), ["A", "C"])
        XCTAssertEqual(calculator.records(records, in: .month).map(\.title), ["A", "B", "C"])
        XCTAssertEqual(calculator.records(records, in: .year).map(\.title), ["A", "B", "C", "E"])
        XCTAssertEqual(calculator.records(records, in: .all).map(\.title), ["A", "B", "C", "E", "F"])
    }

    func testSummary() {
        let records = [
            record("Hades", date(2026, 9, 29), 60),
            record("hades ", date(2026, 9, 29, 20), 30),
            record("Celeste", date(2026, 9, 28), 45),
        ]
        let summary = calculator.summary(of: records)
        XCTAssertEqual(summary.totalMinutes, 135)
        XCTAssertEqual(summary.sessionCount, 3)
        XCTAssertEqual(summary.gamesPlayed, 2)
        XCTAssertEqual(summary.daysPlayed, 2)
        XCTAssertEqual(summary.averageSessionMinutes, 45)
        XCTAssertEqual(calculator.summary(of: []).averageSessionMinutes, 0)
    }

    func testWeekRangeHasSevenDailyBucketsWithZeros() {
        let records = [
            record("A", date(2026, 9, 30, 9), 30),
            record("B", date(2026, 9, 30, 10), 30),
            record("C", date(2026, 9, 25), 90),
            record("Old", date(2026, 9, 1), 500),
        ]
        let buckets = calculator.timeBuckets(records, range: .week)
        XCTAssertEqual(buckets.count, 7)
        XCTAssertEqual(buckets.first?.start, date(2026, 9, 24, 0))
        XCTAssertEqual(buckets.last?.start, date(2026, 9, 30, 0))
        XCTAssertEqual(buckets.map(\.minutes), [0, 90, 0, 0, 0, 0, 60])
        XCTAssertEqual(buckets.last?.hours, 1)
    }

    func testAllTimeUsesMonthlyBucketsFromFirstRecord() {
        let records = [
            record("A", date(2026, 7, 15), 60),
            record("B", date(2026, 9, 2), 120),
        ]
        let buckets = calculator.timeBuckets(records, range: .all)
        XCTAssertEqual(buckets.map(\.start), [date(2026, 7, 1, 0), date(2026, 8, 1, 0), date(2026, 9, 1, 0)])
        XCTAssertEqual(buckets.map(\.minutes), [60, 0, 120])
        XCTAssertEqual(calculator.timeBuckets([], range: .all), [])
    }

    func testMonthRangeUsesWeeklyBuckets() {
        let buckets = calculator.timeBuckets([record("A", date(2026, 9, 29), 30)], range: .month)
        // The range starts Tuesday 1 Sep 2026, whose week starts Monday 31 Aug.
        XCTAssertEqual(buckets.first?.start, date(2026, 8, 31, 0))
        XCTAssertEqual(buckets.last?.start, date(2026, 9, 28, 0))
        XCTAssertEqual(buckets.count, 5)
        XCTAssertEqual(buckets.last?.minutes, 30)
    }

    func testTopGamesGroupTitlesAndLimit() {
        let records = [
            record("hades", date(2026, 9, 1), 30),
            record("Hades", date(2026, 9, 5), 60),
            record("Celeste", date(2026, 9, 2), 80),
            record("Tunic", date(2026, 9, 3), 10),
            record("  ", date(2026, 9, 3), 999),
        ]
        let top = calculator.topGames(records, limit: 2)
        XCTAssertEqual(top.map(\.name), ["Hades", "Celeste"])
        XCTAssertEqual(top.map(\.minutes), [90, 80])
    }

    func testPlatformSharesMergeCaseAndLabelBlankAsUnknown() {
        let records = [
            record("A", now, 30, platform: "PC"),
            record("B", now, 30, platform: "pc"),
            record("C", now, 45, platform: ""),
            record("D", now, 10, platform: "Switch"),
        ]
        let shares = calculator.platformShares(records)
        XCTAssertEqual(shares.map(\.name), ["PC", StatsCalculator.unknownPlatform, "Switch"])
        XCTAssertEqual(shares.map(\.minutes), [60, 45, 10])
    }

    func testStreaks() {
        let records = [
            record("A", date(2026, 9, 29), 10),
            record("A", date(2026, 9, 28), 10),
            record("A", date(2026, 9, 28, 20), 10),
            record("A", date(2026, 9, 10), 10),
            record("A", date(2026, 9, 11), 10),
            record("A", date(2026, 9, 12), 10),
            record("A", date(2026, 9, 13), 10),
        ]
        // Nothing logged today yet, so the current streak runs through yesterday.
        XCTAssertEqual(calculator.streaks(records), .init(current: 2, longest: 4))

        let withToday = records + [record("A", date(2026, 9, 30, 8), 10)]
        XCTAssertEqual(calculator.streaks(withToday), .init(current: 3, longest: 4))

        let broken = [record("A", date(2026, 9, 27), 10)]
        XCTAssertEqual(calculator.streaks(broken), .init(current: 0, longest: 1))
        XCTAssertEqual(calculator.streaks([]), .init())
    }

    func testHeatmapStartsOnWeekBoundaryAndEndsToday() {
        let records = [
            record("A", date(2026, 9, 30, 9), 20),
            record("B", date(2026, 9, 30, 11), 25),
            record("C", date(2026, 9, 21), 60),
            record("Old", date(2026, 1, 1), 60),
        ]
        let days = calculator.heatmap(records, weeks: 2)
        XCTAssertEqual(days.first?.start, date(2026, 9, 21, 0)) // Monday of last week
        XCTAssertEqual(days.last?.start, date(2026, 9, 30, 0))
        XCTAssertEqual(days.count, 10)
        XCTAssertEqual(days.first?.minutes, 60)
        XCTAssertEqual(days.last?.minutes, 45)
        XCTAssertEqual(days.map(\.minutes).reduce(0, +), 105)
    }

    func testEnjoymentTrendAveragesRatedSessionsPerBucket() {
        let records = [
            record("A", date(2026, 9, 29, 9), 10, enjoyment: 4),
            record("B", date(2026, 9, 29, 20), 10, enjoyment: 5),
            record("C", date(2026, 9, 29, 21), 10),
            record("D", date(2026, 9, 26), 10, enjoyment: 2),
        ]
        let trend = calculator.enjoymentTrend(records, range: .week)
        XCTAssertEqual(trend.map(\.start), [date(2026, 9, 26, 0), date(2026, 9, 29, 0)])
        XCTAssertEqual(trend.map(\.average), [2, 4.5])
    }

    func testRecordClampsNegativeMinutes() {
        XCTAssertEqual(StatsRecord(title: "A", start: now, minutes: -5).minutes, 0)
    }
}
