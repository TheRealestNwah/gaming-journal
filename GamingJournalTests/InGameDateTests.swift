import XCTest
@testable import GamingJournal

final class InGameDateTests: XCTestCase {
    func testTamrielDayMovesOn() {
        XCTAssertEqual(InGameDate.nextDay(after: "16th of Last Seed, 4E 201"), "17th of Last Seed, 4E 201")
        XCTAssertEqual(InGameDate.nextDay(after: "1st of Morning Star"), "2nd of Morning Star")
        XCTAssertEqual(InGameDate.nextDay(after: "22 of Frostfall"), "23rd of Frostfall")
    }

    func testMonthAndYearRollOver() {
        XCTAssertEqual(InGameDate.nextDay(after: "31st of Last Seed, 4E 201"), "1st of Hearthfire, 4E 201")
        XCTAssertEqual(InGameDate.nextDay(after: "28th of Sun's Dawn"), "1st of First Seed")
        XCTAssertEqual(InGameDate.nextDay(after: "31st of Evening Star, 3E 427"), "1st of Morning Star, 3E 428")
    }

    func testWeekdayMovesWithTheDay() {
        XCTAssertEqual(InGameDate.nextDay(after: "Sundas, 17th of Last Seed, 4E 201"), "Morndas, 18th of Last Seed, 4E 201")
        XCTAssertEqual(InGameDate.nextDay(after: "Loredas, 1st of Midyear"), "Sundas, 2nd of Midyear")
    }

    func testMonthNamesAreMatchedWhateverTheCase() {
        XCTAssertEqual(InGameDate.nextDay(after: "5th of last seed"), "6th of Last Seed")
    }

    func testDayCounts() {
        XCTAssertEqual(InGameDate.nextDay(after: "Day 12"), "Day 13")
        XCTAssertEqual(InGameDate.nextDay(after: "day 3 of the siege"), "day 4 of the siege")
    }

    func testUnknownDatesAreLeftAlone() {
        XCTAssertNil(InGameDate.nextDay(after: ""))
        XCTAssertNil(InGameDate.nextDay(after: "The morning after the storm"))
        XCTAssertNil(InGameDate.nextDay(after: "12th of Nevermonth"))
    }

    func testOrdinals() {
        XCTAssertEqual([1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 31].map(InGameDate.ordinal),
                       ["1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st", "22nd", "23rd", "31st"])
    }
}
