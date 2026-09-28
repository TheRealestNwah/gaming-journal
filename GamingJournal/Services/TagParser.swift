import Foundation

enum TagParser {
    /// Splits free text on commas, `#` and newlines. Spaces are allowed inside a tag:
    /// "boss, #coop, late night" → ["boss", "coop", "late night"].
    static func parse(_ text: String) -> [String] {
        normalize(text.components(separatedBy: CharacterSet(charactersIn: ",#\n")))
    }

    /// Trims, drops empties, collapses inner whitespace and removes case-insensitive duplicates
    /// (keeping the first spelling).
    static func normalize(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in tags {
            let tag = raw
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
            guard !tag.isEmpty else { continue }
            if seen.insert(tag.lowercased()).inserted {
                result.append(tag)
            }
        }
        return result
    }
}
