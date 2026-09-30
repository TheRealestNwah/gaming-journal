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

    func testHarptosDaysKeepTheWritersStyle() {
        XCTAssertEqual(InGameDate.nextDay(after: "15 Mirtul, 1492 DR"), "16 Mirtul, 1492 DR")
        XCTAssertEqual(InGameDate.nextDay(after: "3rd of Ches"), "4th of Ches")
        XCTAssertEqual(InGameDate.nextDay(after: "9 eleint 1492 DR"), "10 Eleint 1492 DR")
    }

    func testHarptosFestivalsFallBetweenMonths() {
        XCTAssertEqual(InGameDate.nextDay(after: "30 Hammer, 1492 DR"), "Midwinter, 1492 DR")
        XCTAssertEqual(InGameDate.nextDay(after: "Midwinter, 1492 DR"), "1 Alturiak, 1492 DR")
        XCTAssertEqual(InGameDate.nextDay(after: "30 Flamerule"), "Midsummer")
        XCTAssertEqual(InGameDate.nextDay(after: "Shieldmeet, 1492 DR"), "1 Eleasis, 1492 DR")
        XCTAssertEqual(InGameDate.nextDay(after: "Feast of the Moon"), "1 Nightal")
        XCTAssertEqual(InGameDate.nextDay(after: "30 Mirtul"), "1 Kythorn")
    }

    func testHarptosYearRollsOver() {
        XCTAssertEqual(InGameDate.nextDay(after: "30 Nightal, 1492 DR"), "1 Hammer, 1493 DR")
    }

    func testRealWorldDates() {
        XCTAssertEqual(InGameDate.nextDay(after: "October 23, 2287"), "October 24, 2287")
        XCTAssertEqual(InGameDate.nextDay(after: "23 October 2287"), "24 October 2287")
        XCTAssertEqual(InGameDate.nextDay(after: "4th of July, 1899"), "5th of July, 1899")
        XCTAssertEqual(InGameDate.nextDay(after: "December 31, 2077"), "January 1, 2078")
        XCTAssertEqual(InGameDate.nextDay(after: "Saturday, October 23, 2077"), "Sunday, October 24, 2077")
    }

    func testRealWorldMonthLengthsAndLeapYears() {
        XCTAssertEqual(InGameDate.nextDay(after: "February 28, 2288"), "February 29, 2288")
        XCTAssertEqual(InGameDate.nextDay(after: "February 28, 2287"), "March 1, 2287")
        XCTAssertEqual(InGameDate.nextDay(after: "April 30"), "May 1")
        XCTAssertNil(InGameDate.nextDay(after: "April 31, 2287"))
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
