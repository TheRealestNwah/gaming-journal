import Foundation

enum PlaytimeFormatter {
    /// "1h 30m", "45m", "2h", or "—" for zero/negative minutes.
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

    /// Stopwatch style: "4:05", "1:02:03". Negative input shows as zero.
    static func clock(fromSeconds seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
