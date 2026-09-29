import Foundation

/// Moves a typed in-game date on by a day, so a new entry can start from "the next day". It
/// understands the Elder Scrolls calendar ("Sundas, 16th of Last Seed, 4E 201") and simple day
/// counts ("Day 12"); anything else is left for the writer to change by hand.
enum InGameDate {
    struct Month {
        let name: String
        let days: Int
    }

    static let tamrielMonths: [Month] = [
        Month(name: "Morning Star", days: 31), Month(name: "Sun's Dawn", days: 28),
        Month(name: "First Seed", days: 31), Month(name: "Rain's Hand", days: 30),
        Month(name: "Second Seed", days: 31), Month(name: "Midyear", days: 30),
        Month(name: "Sun's Height", days: 31), Month(name: "Last Seed", days: 31),
        Month(name: "Hearthfire", days: 30), Month(name: "Frostfall", days: 31),
        Month(name: "Sun's Dusk", days: 30), Month(name: "Evening Star", days: 31),
    ]

    static let tamrielWeekdays = ["Sundas", "Morndas", "Tirdas", "Middas", "Turdas", "Fredas", "Loredas"]

    /// The day after `text`, or nil when the date isn't one it recognises.
    static func nextDay(after text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return nextTamrielDay(after: trimmed) ?? nextNumberedDay(after: trimmed)
    }

    /// "1st", "2nd", "3rd", "4th", "11th", "22nd"…
    static func ordinal(_ day: Int) -> String {
        let suffix: String
        switch (day % 10, day % 100) {
        case (_, 11...13): suffix = "th"
        case (1, _): suffix = "st"
        case (2, _): suffix = "nd"
        case (3, _): suffix = "rd"
        default: suffix = "th"
        }
        return "\(day)\(suffix)"
    }

    // MARK: Tamriel

    private static let tamrielPattern: NSRegularExpression = {
        let months = tamrielMonths.map { NSRegularExpression.escapedPattern(for: $0.name) }.joined(separator: "|")
        let weekdays = tamrielWeekdays.joined(separator: "|")
        // Optional weekday, day with an optional ordinal suffix, the month, then the rest (era, year).
        let pattern = "^(?:(\(weekdays)),\\s*)?(\\d{1,2})(?:st|nd|rd|th)?\\s+of\\s+(\(months))(.*)$"
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    private static let eraYear = try! NSRegularExpression(pattern: "(\\d+)\\s*E\\s*(\\d+)", options: [.caseInsensitive])

    private static func nextTamrielDay(after text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = tamrielPattern.firstMatch(in: text, range: range),
              let dayRange = Range(match.range(at: 2), in: text),
              let monthRange = Range(match.range(at: 3), in: text),
              let restRange = Range(match.range(at: 4), in: text),
              let day = Int(text[dayRange]),
              let monthIndex = tamrielMonths.firstIndex(where: { $0.name.caseInsensitiveCompare(String(text[monthRange])) == .orderedSame })
        else { return nil }

        var nextDay = day + 1
        var nextMonth = monthIndex
        var rest = String(text[restRange])
        if nextDay > tamrielMonths[monthIndex].days {
            nextDay = 1
            nextMonth = (monthIndex + 1) % tamrielMonths.count
            if nextMonth == 0 {
                rest = incrementingYear(in: rest)
            }
        }

        var result = "\(ordinal(nextDay)) of \(tamrielMonths[nextMonth].name)\(rest)"
        if let weekdayRange = Range(match.range(at: 1), in: text),
           let weekday = tamrielWeekdays.firstIndex(where: { $0.caseInsensitiveCompare(String(text[weekdayRange])) == .orderedSame }) {
            result = "\(tamrielWeekdays[(weekday + 1) % tamrielWeekdays.count]), \(result)"
        }
        return result
    }

    /// "…, 4E 201" becomes "…, 4E 202".
    private static func incrementingYear(in text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = eraYear.firstMatch(in: text, range: range),
              let yearRange = Range(match.range(at: 2), in: text),
              let year = Int(text[yearRange])
        else { return text }
        return text.replacingCharacters(in: yearRange, with: String(year + 1))
    }

    // MARK: Day counts

    private static let dayPattern = try! NSRegularExpression(pattern: "^(day)\\s+(\\d+)(.*)$", options: [.caseInsensitive])

    private static func nextNumberedDay(after text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = dayPattern.firstMatch(in: text, range: range),
              let wordRange = Range(match.range(at: 1), in: text),
              let numberRange = Range(match.range(at: 2), in: text),
              let restRange = Range(match.range(at: 3), in: text),
              let number = Int(text[numberRange])
        else { return nil }
        return "\(text[wordRange]) \(number + 1)\(text[restRange])"
    }
}
