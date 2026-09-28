import Foundation
import WidgetKit

/// What the widgets show, written by the app to the shared App Group. The widget extension has a
/// mirror of this type (`GamingJournalWidgets/Snapshot.swift`); keep the two in step.
struct WidgetSnapshot: Codable, Equatable {
    static let appGroup = "group.com.gamingjournal.GamingJournal"
    static let key = "widgetSnapshot"
    /// Opened by the start-session widget.
    static let startTimerURL = URL(string: "gamingjournal://start-timer")!

    struct LastSession: Codable, Equatable {
        var title: String
        var platform: String
        var start: Date
        var minutes: Int
    }

    struct Timer: Codable, Equatable {
        var title: String
        /// Seconds counted before the current run.
        var accumulated: TimeInterval
        /// Start of the current run, or nil while paused.
        var runningSince: Date?
    }

    struct Game: Codable, Equatable {
        var title: String
        var minutes: Int
    }

    var generatedAt: Date
    var lastSession: LastSession?
    var timer: Timer?
    /// Minutes played since the start of this week.
    var weekMinutes: Int
    var weekStart: Date
    var topGames: [Game]

    static func make(
        sessions: [StatsRecord],
        timer: TimerState?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> WidgetSnapshot {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        let thisWeek = sessions.filter { $0.start >= weekStart && $0.start <= now }
        let latest = sessions.filter { $0.start <= now }.max { $0.start < $1.start }
        return WidgetSnapshot(
            generatedAt: now,
            lastSession: latest.map {
                LastSession(title: $0.title, platform: $0.platform, start: $0.start, minutes: $0.minutes)
            },
            timer: timer.map { Timer(title: $0.gameTitle, accumulated: $0.accumulated, runningSince: $0.runningSince) },
            weekMinutes: thisWeek.reduce(0) { $0 + $1.minutes },
            weekStart: weekStart,
            topGames: StatsCalculator(calendar: calendar, now: now)
                .topGames(thisWeek, limit: 3)
                .map { Game(title: $0.name, minutes: $0.minutes) }
        )
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> WidgetSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(WidgetSnapshot.self, from: data)
    }

    /// Stores the snapshot for the widgets and asks them to refresh, skipping both when nothing
    /// they display has changed.
    func publish(to defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) {
        guard let defaults, let data = try? encoded() else { return }
        if let old = defaults.data(forKey: Self.key).flatMap({ try? Self.decode($0) }), old.sameContent(as: self) {
            return
        }
        defaults.set(data, forKey: Self.key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Equal apart from `generatedAt`.
    func sameContent(as other: WidgetSnapshot) -> Bool {
        var copy = other
        copy.generatedAt = generatedAt
        return copy == self
    }
}
