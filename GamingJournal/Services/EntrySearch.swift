import Foundation

/// Finds entries by their words or in-game date. Every word typed must appear somewhere in the
/// entry; case and accents don't matter.
enum EntrySearch {
    /// An entry that matched, ready to list.
    struct Result: Identifiable, Equatable {
        var journalID: UUID
        var entryID: UUID
        var characterName: String
        var heading: String
        /// The words around the first match, or the entry's opening words when only the date matched.
        var snippet: String

        var id: UUID { entryID }
    }

    /// The words of a query; empty when there's nothing to search for.
    static func terms(in query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// Whether every term appears in the heading or the body.
    static func matches(heading: String, body: String, terms: [String]) -> Bool {
        guard !terms.isEmpty else { return false }
        return terms.allSatisfy { term in
            heading.range(of: term, options: options) != nil || body.range(of: term, options: options) != nil
        }
    }

    /// Every matching entry across `journals`, newest first. A blank query finds nothing.
    static func results(for query: String, in journals: [Journal], locale: Locale = .current) -> [Result] {
        let terms = terms(in: query)
        guard !terms.isEmpty else { return [] }
        return journals
            .flatMap { journal in (journal.entries ?? []).map { (journal, $0) } }
            .filter { journal, entry in matches(heading: entry.heading(locale: locale), body: entry.body, terms: terms) }
            .sorted { ($0.1.writtenAt, $0.1.createdAt) > ($1.1.writtenAt, $1.1.createdAt) }
            .map { journal, entry in
                Result(
                    journalID: journal.id,
                    entryID: entry.id,
                    characterName: journal.characterName,
                    heading: entry.heading(locale: locale),
                    snippet: snippet(of: entry.body, around: terms)
                )
            }
    }

    /// A line of the body around the first term it contains, trimmed at word boundaries, with "…"
    /// where it was cut. Falls back to the opening words when no term is in the body.
    static func snippet(of body: String, around terms: [String], radius: Int = 40, length: Int = 110) -> String {
        let flat = body.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard let match = terms.lazy.compactMap({ flat.range(of: $0, options: options) }).first else {
            return opening(of: flat, length: length)
        }
        var start = flat.index(match.lowerBound, offsetBy: -radius, limitedBy: flat.startIndex) ?? flat.startIndex
        if start > flat.startIndex {
            // Start on a whole word.
            start = flat[start..<match.lowerBound].firstIndex(of: " ").map { flat.index(after: $0) } ?? match.lowerBound
        }
        let tail = flat[start...]
        var text = String(tail)
        if tail.count > length {
            let cut = tail.index(tail.startIndex, offsetBy: length)
            let end = tail[..<cut].lastIndex(of: " ").flatMap { $0 > match.upperBound ? $0 : nil } ?? cut
            text = String(tail[..<end]) + "…"
        }
        return (start > flat.startIndex ? "…" : "") + text
    }

    /// The first words of `body`, trimmed to `length` characters at a word boundary.
    static func opening(of body: String, length: Int = 110) -> String {
        let flat = body.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard flat.count > length else { return flat }
        let cut = flat.index(flat.startIndex, offsetBy: length)
        let end = flat[..<cut].lastIndex(of: " ") ?? cut
        return String(flat[..<end]) + "…"
    }

    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
}
