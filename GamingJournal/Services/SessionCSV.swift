import Foundation

/// Spreadsheet-friendly export of sessions. Photos aren't included; use the JSON backup for that.
enum SessionCSV {
    static let header = [
        "id", "game", "platform", "start", "duration_minutes", "enjoyment", "mood",
        "milestone", "milestone_note", "tags", "notes",
    ]

    static func export(_ sessions: [JournalBackup.Session]) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = [header.joined(separator: ",")]
        for session in sessions.sorted(by: { $0.startDate < $1.startDate }) {
            let fields = [
                session.id.uuidString,
                session.gameTitle,
                session.platform,
                formatter.string(from: session.startDate),
                String(session.durationMinutes),
                session.enjoyment.map(String.init) ?? "",
                session.mood ?? "",
                session.isMilestone ? "yes" : "no",
                session.milestoneNote,
                session.tags.joined(separator: "; "),
                session.notes,
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// RFC 4180: quote fields containing commas, quotes, line breaks or edge spaces; double inner quotes.
    static func escape(_ field: String) -> String {
        let needsQuotes = field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline })
            || field.hasPrefix(" ") || field.hasSuffix(" ")
        guard needsQuotes else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
