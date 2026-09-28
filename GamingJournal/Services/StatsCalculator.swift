import Foundation

/// Period the Stats tab covers.
enum StatsRange: String, CaseIterable, Identifiable {
    case week, month, year, all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: "7D"
        case .month: "30D"
        case .year: "1Y"
        case .all: "All"
        }
    }

    /// Bar size for the time chart.
    var bucket: Calendar.Component {
        switch self {
        case .week: .day
        case .month: .weekOfYear
        case .year, .all: .month
        }
    }

    /// Start of the range (inclusive), or nil for all time. 7D and 30D include today.
    func start(now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .week: return calendar.date(byAdding: .day, value: -6, to: today)
        case .month: return calendar.date(byAdding: .day, value: -29, to: today)
        case .year: return calendar.date(byAdding: .year, value: -1, to: today)
        case .all: return nil
        }
    }
}

/// Plain copy of the fields stats need, so the calculator is independent of SwiftData.
struct StatsRecord: Equatable {
    var title: String
    var platform: String
    var start: Date
    var minutes: Int
    var enjoyment: Int?

    init(title: String, platform: String = "", start: Date, minutes: Int, enjoyment: Int? = nil) {
        self.title = title
        self.platform = platform
        self.start = start
        self.minutes = max(0, minutes)
        self.enjoyment = enjoyment
    }

    init(session: PlaySession) {
        self.init(
            title: session.gameTitle,
            platform: session.platform,
            start: session.startDate,
            minutes: session.durationMinutes,
            enjoyment: session.enjoyment
        )
    }
}

struct StatsCalculator {
    struct Summary: Equatable {
        var totalMinutes = 0
        var sessionCount = 0
        var gamesPlayed = 0
        var daysPlayed = 0

        var averageSessionMinutes: Int {
            sessionCount == 0 ? 0 : Int((Double(totalMinutes) / Double(sessionCount)).rounded())
        }
    }

    struct Bucket: Equatable, Identifiable {
        var start: Date
        var minutes: Int
        var id: Date { start }
        var hours: Double { Double(minutes) / 60 }
    }

    struct Share: Equatable, Identifiable {
        var name: String
        var minutes: Int
        var id: String { name }
        var hours: Double { Double(minutes) / 60 }
    }

    struct TrendPoint: Equatable, Identifiable {
        var start: Date
        var average: Double
        var id: Date { start }
    }

    struct Streaks: Equatable {
        var current = 0
        var longest = 0
    }

    static let unknownPlatform = "Unknown"

    let calendar: Calendar
    let now: Date

    init(calendar: Calendar = .current, now: Date = .now) {
        self.calendar = calendar
        self.now = now
    }

    /// Records whose start falls within the range and not in the future.
    func records(_ records: [StatsRecord], in range: StatsRange) -> [StatsRecord] {
        let start = range.start(now: now, calendar: calendar)
        return records.filter { record in
            record.start <= now && (start.map { record.start >= $0 } ?? true)
        }
    }

    func summary(of records: [StatsRecord]) -> Summary {
        Summary(
            totalMinutes: records.reduce(0) { $0 + $1.minutes },
            sessionCount: records.count,
            gamesPlayed: Set(records.map { GameTitleIndex.key(for: $0.title) }.filter { !$0.isEmpty }).count,
            daysPlayed: Set(records.map { calendar.startOfDay(for: $0.start) }).count
        )
    }

    /// Minutes per bucket across the whole range, including empty buckets. For all time the range
    /// runs from the earliest record's bucket to now.
    func timeBuckets(_ records: [StatsRecord], range: StatsRange) -> [Bucket] {
        let inRange = self.records(records, in: range)
        let component = range.bucket
        guard let rangeStart = range.start(now: now, calendar: calendar) ?? inRange.map(\.start).min(),
              let first = bucketStart(of: rangeStart, component),
              let last = bucketStart(of: now, component)
        else { return [] }

        var totals: [Date: Int] = [:]
        for record in inRange {
            if let key = bucketStart(of: record.start, component) {
                totals[key, default: 0] += record.minutes
            }
        }

        var buckets: [Bucket] = []
        var cursor = first
        while cursor <= last {
            buckets.append(Bucket(start: cursor, minutes: totals[cursor] ?? 0))
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor) else { break }
            cursor = next
        }
        return buckets
    }

    /// Games by total time, most first; titles grouped like `GameTitleIndex`, shown with the most
    /// recent spelling.
    func topGames(_ records: [StatsRecord], limit: Int = 5) -> [Share] {
        var minutes: [String: Int] = [:]
        var spelling: [String: (title: String, date: Date)] = [:]
        for record in records {
            let key = GameTitleIndex.key(for: record.title)
            guard !key.isEmpty else { continue }
            minutes[key, default: 0] += record.minutes
            if let current = spelling[key], current.date > record.start { continue }
            spelling[key] = (record.title, record.start)
        }
        return minutes
            .map { Share(name: spelling[$0.key]?.title ?? $0.key, minutes: $0.value) }
            .sorted { $0.minutes != $1.minutes ? $0.minutes > $1.minutes : $0.name < $1.name }
            .prefix(limit)
            .map { $0 }
    }

    /// Time per platform, most first. Platforms compare case-insensitively; blank ones are "Unknown".
    func platformShares(_ records: [StatsRecord]) -> [Share] {
        var minutes: [String: Int] = [:]
        var names: [String: String] = [:]
        for record in records {
            let name = record.platform.trimmingCharacters(in: .whitespacesAndNewlines)
            let display = name.isEmpty ? Self.unknownPlatform : name
            let key = display.lowercased()
            minutes[key, default: 0] += record.minutes
            if names[key] == nil { names[key] = display }
        }
        return minutes
            .map { Share(name: names[$0.key] ?? $0.key, minutes: $0.value) }
            .sorted { $0.minutes != $1.minutes ? $0.minutes > $1.minutes : $0.name < $1.name }
    }

    /// Current streak counts consecutive played days ending today, or yesterday if today has no
    /// session yet. Longest is the best run ever.
    func streaks(_ records: [StatsRecord]) -> Streaks {
        let days = Set(records.filter { $0.start <= now }.map { calendar.startOfDay(for: $0.start) })
        guard !days.isEmpty else { return Streaks() }

        var longest = 0
        for day in days {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day), !days.contains(previous) else {
                continue
            }
            var length = 1
            var cursor = day
            while let next = calendar.date(byAdding: .day, value: 1, to: cursor), days.contains(next) {
                length += 1
                cursor = next
            }
            longest = max(longest, length)
        }

        let today = calendar.startOfDay(for: now)
        var cursor = days.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var current = 0
        while days.contains(cursor) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return Streaks(current: current, longest: longest)
    }

    /// Minutes per day for the last `weeks` whole weeks up to today, oldest first. The first day
    /// is the start of a week so the grid lines up in columns.
    func heatmap(_ records: [StatsRecord], weeks: Int = 17) -> [Bucket] {
        let today = calendar.startOfDay(for: now)
        guard weeks > 0,
              let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let first = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeek)
        else { return [] }

        var totals: [Date: Int] = [:]
        for record in records where record.start >= first && record.start <= now {
            totals[calendar.startOfDay(for: record.start), default: 0] += record.minutes
        }

        var days: [Bucket] = []
        var cursor = first
        while cursor <= today {
            days.append(Bucket(start: cursor, minutes: totals[cursor] ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    /// Average enjoyment per bucket, only for buckets with rated sessions.
    func enjoymentTrend(_ records: [StatsRecord], range: StatsRange) -> [TrendPoint] {
        var ratings: [Date: [Int]] = [:]
        for record in self.records(records, in: range) {
            guard let rating = record.enjoyment, let key = bucketStart(of: record.start, range.bucket) else { continue }
            ratings[key, default: []].append(rating)
        }
        return ratings
            .map { TrendPoint(start: $0.key, average: Double($0.value.reduce(0, +)) / Double($0.value.count)) }
            .sorted { $0.start < $1.start }
    }

    private func bucketStart(of date: Date, _ component: Calendar.Component) -> Date? {
        component == .day ? calendar.startOfDay(for: date) : calendar.dateInterval(of: component, for: date)?.start
    }
}
