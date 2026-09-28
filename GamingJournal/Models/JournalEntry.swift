import Foundation
import SwiftData

/// A single journal entry about a play session.
@Model
final class JournalEntry {
    var gameTitle: String
    var platform: String
    var date: Date
    var minutesPlayed: Int
    var notes: String
    /// 1–5 stars, or nil when unrated.
    var rating: Int?

    init(
        gameTitle: String,
        platform: String = "",
        date: Date = .now,
        minutesPlayed: Int = 0,
        notes: String = "",
        rating: Int? = nil
    ) {
        self.gameTitle = gameTitle
        self.platform = platform
        self.date = date
        self.minutesPlayed = max(0, minutesPlayed)
        self.notes = notes
        self.rating = rating.map { min(5, max(1, $0)) }
    }

    /// "1h 30m", "45m", or "—" when no time was logged.
    var formattedDuration: String {
        PlaytimeFormatter.string(fromMinutes: minutesPlayed)
    }
}

enum PlaytimeFormatter {
    static func string(fromMinutes minutes: Int) -> String {
        guard minutes > 0 else { return "—" }
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest)m"
        case (_, 0): return "\(hours)h"
        default: return "\(hours)h \(rest)m"
        }
    }
}
