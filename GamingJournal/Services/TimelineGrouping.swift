import Foundation

/// Groups sessions into months and days for the journal timeline, newest first.
enum TimelineGrouping {
    struct Day: Identifiable {
        /// Start of the day in the grouping calendar.
        let date: Date
        let sessions: [PlaySession]

        var id: Date { date }

        var totalMinutes: Int {
            sessions.reduce(0) { $0 + max(0, $1.durationMinutes) }
        }
    }

    struct Month: Identifiable {
        /// Start of the month in the grouping calendar.
        let date: Date
        let days: [Day]

        var id: Date { date }

        var totalMinutes: Int {
            days.reduce(0) { $0 + $1.totalMinutes }
        }
    }

    /// Months newest first; days within a month newest first; sessions within a day by start time,
    /// latest first.
    static func months(from sessions: [PlaySession], calendar: Calendar = .current) -> [Month] {
        let byDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startDate) }
        let days = byDay
            .map { date, sessions in
                Day(date: date, sessions: sessions.sorted { $0.startDate > $1.startDate })
            }
            .sorted { $0.date > $1.date }

        var months: [Month] = []
        for day in days {
            let monthStart = calendar.dateInterval(of: .month, for: day.date)?.start ?? day.date
            if let last = months.last, last.date == monthStart {
                months[months.count - 1] = Month(date: monthStart, days: last.days + [day])
            } else {
                months.append(Month(date: monthStart, days: [day]))
            }
        }
        return months
    }
}
