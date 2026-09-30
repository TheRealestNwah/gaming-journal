import Foundation

/// Turns a journal into a readable Markdown book: its title, then every entry in order under its
/// date, the way it reads in the app.
enum JournalMarkdown {
    static func render(_ journal: Journal, locale: Locale = .current) -> String {
        var lines = ["# \(journal.title)"]
        if !journal.subtitle.isEmpty {
            lines.append("*\(journal.subtitle)*")
        }
        for entry in journal.story {
            lines.append("")
            lines.append("## \(entry.heading(locale: locale))")
            if !entry.place.isEmpty {
                lines.append("*\(entry.place)*")
            }
            if !entry.body.isEmpty {
                lines.append("")
                lines.append(entry.body)
            }
            let photos = entry.photos?.count ?? 0
            if photos > 0 {
                lines.append("")
                lines.append("*\(photos) picture\(photos == 1 ? "" : "s") in the app*")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// A file name from the character's name, without characters file systems reject.
    static func filename(for journal: Journal) -> String {
        let cleaned = journal.title
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined()
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Journal" : cleaned
    }
}
