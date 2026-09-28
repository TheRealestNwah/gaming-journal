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
}
