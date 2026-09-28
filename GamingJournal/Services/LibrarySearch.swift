import Foundation

/// Search across every notebook: which tales match by name, and which entries match the words.
/// Entry matching is the chronicle's own search, so both find the same pages.
enum LibrarySearch {
    struct Result: Identifiable {
        var notebook: Notebook
        /// The notebook's title, game or platform matched.
        var matchesNotebook: Bool
        /// Matching entries, newest first.
        var entries: [Entry]

        var id: UUID { notebook.id }
    }

    /// Notebooks with something matching, most recently touched first. Empty for a blank query.
    static func results(for query: String, in notebooks: [Notebook]) -> [Result] {
        let words = ChronicleFilter.normalize(query).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        let filter = ChronicleFilter(searchText: query)
        return notebooks
            .sorted { $0.updatedAt > $1.updatedAt }
            .compactMap { notebook in
                let name = ChronicleFilter.normalize([notebook.title, notebook.gameTitle, notebook.platform].joined(separator: " "))
                let matchesNotebook = words.allSatisfy { name.contains($0) }
                let entries = notebook.chronicle.filter(filter.matches)
                guard matchesNotebook || !entries.isEmpty else { return nil }
                return Result(notebook: notebook, matchesNotebook: matchesNotebook, entries: entries)
            }
    }

    /// A short piece of the body around the first word that matched, so a result shows why it
    /// matched. Falls back to the opening when the match is in the title or elsewhere.
    static func excerpt(of text: String, matching query: String, radius: Int = 60) -> String {
        let flat = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !flat.isEmpty else { return "" }
        let words = ChronicleFilter.normalize(query).split(separator: " ")
        let hit = words.lazy.compactMap { flat.range(of: $0, options: .caseInsensitive) }.first
        guard let hit else { return clip(flat, from: flat.startIndex, radius: radius * 2) }

        let start = flat.index(hit.lowerBound, offsetBy: -radius, limitedBy: flat.startIndex) ?? flat.startIndex
        // Start on a word boundary.
        let wordStart = start == flat.startIndex ? start : (flat[start...].firstIndex(of: " ").map { flat.index(after: $0) } ?? start)
        let clipped = clip(flat, from: min(wordStart, hit.lowerBound), radius: radius * 2)
        return wordStart > flat.startIndex ? "…" + clipped : clipped
    }

    private static func clip(_ text: String, from start: String.Index, radius: Int) -> String {
        let end = text.index(start, offsetBy: radius, limitedBy: text.endIndex) ?? text.endIndex
        guard end < text.endIndex else { return String(text[start...]) }
        // End on a word boundary.
        let wordEnd = text[start..<end].lastIndex(of: " ") ?? end
        return String(text[start..<wordEnd]) + "…"
    }
}
