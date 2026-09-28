import Foundation

/// Turns a notebook into a readable Markdown "book": title page, the party, then every entry in
/// order, like a finished journal.
enum NotebookMarkdown {
    static func render(_ notebook: Notebook, calendar: Calendar = .current, locale: Locale = .current) -> String {
        var lines: [String] = []
        lines.append("# \(notebook.title)")
        let subtitle = [notebook.gameTitle, notebook.platform].filter { !$0.isEmpty }.joined(separator: " · ")
        if !subtitle.isEmpty {
            lines.append("*\(subtitle)*")
        }
        lines.append("")
        lines.append("\(notebook.status.label) · begun \(format(notebook.startedAt, time: false, locale: locale))")
        if !notebook.summary.isEmpty {
            lines.append("")
            lines.append(contentsOf: notebook.summary.split(separator: "\n", omittingEmptySubsequences: false).map { "> \($0)" })
        }

        let party = notebook.party
        if !party.isEmpty {
            lines.append("")
            lines.append("## The Party")
            lines.append("")
            for member in party {
                var line = "- **\(member.name)**"
                if !member.role.isEmpty { line += ", \(member.role)" }
                if member.isRetired { line += " *(retired)*" }
                lines.append(line)
                if !member.backstory.isEmpty {
                    lines.append("  \(member.backstory.replacingOccurrences(of: "\n", with: " "))")
                }
            }
        }

        let entries = (notebook.entries ?? []).sorted { ($0.writtenAt, $0.createdAt) < ($1.writtenAt, $1.createdAt) }
        if !entries.isEmpty {
            lines.append("")
            lines.append("## Chronicle")
            for entry in entries {
                lines.append("")
                let heading = entry.title.isEmpty ? format(entry.writtenAt, time: false, locale: locale) : entry.title
                lines.append("### \(entry.isTurningPoint ? "✦ " : "")\(heading)")
                var meta = ["*\(entry.author?.name ?? "Narrator")*", format(entry.writtenAt, time: true, locale: locale)]
                if !entry.inGameDate.isEmpty { meta.append(entry.inGameDate) }
                if !entry.place.isEmpty { meta.append(entry.place) }
                if !entry.quest.isEmpty { meta.append("Quest: \(entry.quest)") }
                lines.append(meta.joined(separator: " · "))
                let feelings = entry.emotions.compactMap { felt in
                    felt.emotion.map { "\($0.label)\(String(repeating: "•", count: felt.intensity))" }
                }
                if !feelings.isEmpty {
                    lines.append("")
                    lines.append("Feeling: \(feelings.joined(separator: ", "))")
                }
                let bonds = entry.bonds.map { "\($0.targetName) (\($0.affinityLabel.lowercased()))" }
                if !bonds.isEmpty {
                    lines.append("Bonds: \(bonds.joined(separator: ", "))")
                }
                if !entry.body.isEmpty {
                    lines.append("")
                    lines.append(entry.body)
                }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func filename(for notebook: Notebook) -> String {
        let cleaned = notebook.title
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined()
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Notebook" : cleaned
    }

    private static func format(_ date: Date, time: Bool, locale: Locale) -> String {
        var style = Date.FormatStyle(date: .long, time: time ? .shortened : .omitted)
        style.locale = locale
        return date.formatted(style)
    }
}
