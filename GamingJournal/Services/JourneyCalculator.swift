import Foundation

/// Adventure-level numbers for one notebook or all of them: time on the road, writing, feelings.
struct JourneyCalculator {
    struct Summary: Equatable {
        var notebookCount = 0
        var completedCount = 0
        /// Calendar days from the earliest start to today (or to completion for finished tales).
        var daysOnJourney = 0
        var entryCount = 0
        var wordCount = 0
        var minutesPlayed = 0
        var turningPoints = 0
    }

    struct GroupShare: Identifiable, Equatable {
        var group: EmotionGroup
        var weight: Int
        var id: EmotionGroup { group }
    }

    struct MonthCount: Identifiable, Equatable {
        var month: Date
        var entries: Int
        var id: Date { month }
    }

    let calendar: Calendar
    let now: Date

    init(calendar: Calendar = .current, now: Date = .now) {
        self.calendar = calendar
        self.now = now
    }

    func summary(of notebooks: [Notebook]) -> Summary {
        let entries = notebooks.flatMap { $0.entries ?? [] }
        let sessions = notebooks.flatMap { $0.sessions ?? [] }
        return Summary(
            notebookCount: notebooks.count,
            completedCount: notebooks.filter { $0.status == .completed }.count,
            daysOnJourney: notebooks.map(daysOnJourney).max() ?? 0,
            entryCount: entries.count,
            wordCount: entries.reduce(0) { $0 + $1.wordCount },
            minutesPlayed: sessions.reduce(0) { $0 + max(0, $1.durationMinutes) },
            turningPoints: entries.filter(\.isTurningPoint).count
        )
    }

    /// Days from the notebook's start to today, or to its last update once completed or abandoned.
    /// A tale started today counts as day one.
    func daysOnJourney(_ notebook: Notebook) -> Int {
        let end = notebook.status == .ongoing ? now : max(notebook.startedAt, notebook.updatedAt)
        let start = calendar.startOfDay(for: notebook.startedAt)
        let days = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: end)).day ?? 0
        return max(1, days + 1)
    }

    /// How much of each emotion family was felt, by total intensity, strongest first.
    func emotionGroups(in entries: [Entry]) -> [GroupShare] {
        var weights: [EmotionGroup: Int] = [:]
        for entry in entries {
            for felt in entry.emotions {
                if let group = felt.emotion?.group {
                    weights[group, default: 0] += felt.intensity
                }
            }
        }
        return EmotionGroup.allCases
            .compactMap { group in weights[group].map { GroupShare(group: group, weight: $0) } }
            .sorted { $0.weight > $1.weight }
    }

    /// Entries per month from the first entry's month to this month, empty months included.
    func entriesPerMonth(_ entries: [Entry]) -> [MonthCount] {
        guard let first = entries.map(\.writtenAt).min(),
              let start = calendar.dateInterval(of: .month, for: first)?.start,
              let end = calendar.dateInterval(of: .month, for: max(now, first))?.start
        else { return [] }
        var counts: [Date: Int] = [:]
        for entry in entries {
            if let month = calendar.dateInterval(of: .month, for: entry.writtenAt)?.start {
                counts[month, default: 0] += 1
            }
        }
        var months: [MonthCount] = []
        var cursor = start
        while cursor <= end {
            months.append(MonthCount(month: cursor, entries: counts[cursor] ?? 0))
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return months
    }
}
