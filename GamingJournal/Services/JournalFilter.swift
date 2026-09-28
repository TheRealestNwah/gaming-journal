import Foundation

/// Search text plus facet filters for the journal timeline. Game, platform and tag compare
/// case- and whitespace-insensitively, like `GameTitleIndex`.
struct JournalFilter: Equatable {
    var searchText = ""
    var game: String?
    var platform: String?
    var tag: String?
    var milestonesOnly = false

    /// True when any facet (not the search text) narrows the list.
    var hasFacets: Bool {
        game != nil || platform != nil || tag != nil || milestonesOnly
    }

    var isActive: Bool {
        hasFacets || !Self.normalize(searchText).isEmpty
    }

    mutating func clearFacets() {
        game = nil
        platform = nil
        tag = nil
        milestonesOnly = false
    }

    func matches(_ session: PlaySession) -> Bool {
        if milestonesOnly && !session.isMilestone { return false }
        if let game, Self.normalize(session.gameTitle) != Self.normalize(game) { return false }
        if let platform, Self.normalize(session.platform) != Self.normalize(platform) { return false }
        if let tag {
            let wanted = Self.normalize(tag)
            if !session.tags.contains(where: { Self.normalize($0) == wanted }) { return false }
        }
        return matchesSearch(session)
    }

    func apply(to sessions: [PlaySession]) -> [PlaySession] {
        isActive ? sessions.filter(matches) : sessions
    }

    /// Every search word must appear in the title, platform, notes, milestone note or a tag.
    private func matchesSearch(_ session: PlaySession) -> Bool {
        let words = Self.normalize(searchText).split(separator: " ")
        guard !words.isEmpty else { return true }
        let haystack = Self.normalize(
            ([session.gameTitle, session.platform, session.notes, session.milestoneNote] + session.tags)
                .joined(separator: " ")
        )
        return words.allSatisfy { haystack.contains($0) }
    }

    static func normalize(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

/// Values available for each facet, drawn from the sessions themselves.
struct JournalFacets: Equatable {
    var games: [String]
    var platforms: [String]
    var tags: [String]

    init(sessions: [PlaySession]) {
        games = Self.distinct(sessions.map(\.gameTitle))
        platforms = Self.distinct(sessions.map(\.platform))
        tags = Self.distinct(sessions.flatMap(\.tags))
    }

    /// Trimmed, non-empty, case-insensitively unique (first spelling wins), sorted alphabetically.
    static func distinct(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { continue }
            result.append(trimmed)
        }
        return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
