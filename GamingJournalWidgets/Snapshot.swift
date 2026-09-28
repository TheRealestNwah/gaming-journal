import Foundation

/// Mirror of the app's `WidgetSnapshot`, which the app writes into the shared App Group.
struct Snapshot: Codable {
    static let appGroup = "group.com.gamingjournal.GamingJournal"
    static let key = "widgetSnapshot"
    static let startTimerURL = URL(string: "gamingjournal://start-timer")!

    struct LastSession: Codable {
        var title: String
        var platform: String
        var start: Date
        var minutes: Int
    }

    struct Timer: Codable {
        var title: String
        var accumulated: TimeInterval
        var runningSince: Date?

        var isPaused: Bool { runningSince == nil }

        /// Where a counting-up clock would have started to show the elapsed time now.
        func clockStart(now: Date) -> Date {
            (runningSince ?? now).addingTimeInterval(-accumulated)
        }

        func elapsed(at now: Date) -> TimeInterval {
            accumulated + (runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
        }
    }

    struct Game: Codable, Hashable {
        var title: String
        var minutes: Int
    }

    var generatedAt: Date
    var lastSession: LastSession?
    var timer: Timer?
    var weekMinutes: Int
    var weekStart: Date
    var topGames: [Game]

    static let placeholder = Snapshot(
        generatedAt: .now,
        lastSession: LastSession(title: "Hades", platform: "Switch", start: .now.addingTimeInterval(-7200), minutes: 75),
        timer: nil,
        weekMinutes: 380,
        weekStart: .now,
        topGames: [
            Game(title: "Hades", minutes: 190),
            Game(title: "Celeste", minutes: 120),
            Game(title: "Balatro", minutes: 70),
        ]
    )

    static func load() -> Snapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(Snapshot.self, from: data)
    }

    /// Week total, or zero when the snapshot is from an earlier week.
    func weekMinutes(now: Date, calendar: Calendar = .current) -> Int {
        let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start
        return currentWeek == weekStart ? weekMinutes : 0
    }

    func topGames(now: Date, calendar: Calendar = .current) -> [Game] {
        calendar.dateInterval(of: .weekOfYear, for: now)?.start == weekStart ? topGames : []
    }
}

enum Format {
    /// "1h 30m", "45m", "2h", or "0m".
    static func minutes(_ minutes: Int) -> String {
        guard minutes > 0 else { return "0m" }
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest)m"
        case (_, 0): return "\(hours)h"
        default: return "\(hours)h \(rest)m"
        }
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
