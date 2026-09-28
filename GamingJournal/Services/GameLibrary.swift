import Foundation

/// A game as seen through its sessions. Titles are grouped with `GameTitleIndex.key(for:)`.
struct GameSummary: Identifiable, Equatable {
    /// Normalised title key; stable while the title's spelling changes case or spacing.
    let key: String
    /// Spelling of the most recent session.
    let title: String
    let sessionCount: Int
    let totalMinutes: Int
    let firstPlayed: Date
    let lastPlayed: Date
    /// Mean of rated sessions, or nil when none are rated.
    let averageEnjoyment: Double?
    let milestoneCount: Int
    /// Platforms used, most recent first.
    let platforms: [String]

    var id: String { key }
}

enum GameLibrary {
    enum SortOrder: String, CaseIterable, Identifiable {
        case recent, mostPlayed, title

        var id: String { rawValue }

        var label: String {
            switch self {
            case .recent: "Recently Played"
            case .mostPlayed: "Most Played"
            case .title: "Title"
            }
        }
    }

    static func summaries(from sessions: [PlaySession], sortedBy order: SortOrder = .recent) -> [GameSummary] {
        let groups = Dictionary(grouping: sessions) { GameTitleIndex.key(for: $0.gameTitle) }
        let summaries = groups.compactMap { key, group -> GameSummary? in
            guard !key.isEmpty else { return nil }
            let newestFirst = group.sorted { $0.startDate > $1.startDate }
            guard let latest = newestFirst.first, let earliest = newestFirst.last else { return nil }
            let ratings = group.compactMap(\.enjoyment)
            var seenPlatforms = Set<String>()
            let platforms = newestFirst.compactMap { session -> String? in
                let platform = session.platform.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !platform.isEmpty, seenPlatforms.insert(platform.lowercased()).inserted else { return nil }
                return platform
            }
            return GameSummary(
                key: key,
                title: latest.gameTitle,
                sessionCount: group.count,
                totalMinutes: group.reduce(0) { $0 + max(0, $1.durationMinutes) },
                firstPlayed: earliest.startDate,
                lastPlayed: latest.startDate,
                averageEnjoyment: ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count),
                milestoneCount: group.filter(\.isMilestone).count,
                platforms: platforms
            )
        }
        return sort(summaries, by: order)
    }

    static func sort(_ summaries: [GameSummary], by order: SortOrder) -> [GameSummary] {
        summaries.sorted { lhs, rhs in
            switch order {
            case .recent:
                if lhs.lastPlayed != rhs.lastPlayed { return lhs.lastPlayed > rhs.lastPlayed }
            case .mostPlayed:
                if lhs.totalMinutes != rhs.totalMinutes { return lhs.totalMinutes > rhs.totalMinutes }
            case .title:
                break
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    /// Sessions of one game, newest first.
    static func sessions(forKey key: String, in sessions: [PlaySession]) -> [PlaySession] {
        sessions
            .filter { GameTitleIndex.key(for: $0.gameTitle) == key }
            .sorted { $0.startDate > $1.startDate }
    }

    /// The title a rename should write. Renaming onto another game's title (in any case or
    /// spacing) adopts that game's spelling so the two merge. Nil when the input is blank.
    static func resolvedTitle(renaming oldTitle: String, to newTitle: String, in sessions: [PlaySession]) -> String? {
        let cleaned = newTitle.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !cleaned.isEmpty else { return nil }
        let oldKey = GameTitleIndex.key(for: oldTitle)
        let newKey = GameTitleIndex.key(for: cleaned)
        if newKey != oldKey,
           let existing = sessions
               .filter({ GameTitleIndex.key(for: $0.gameTitle) == newKey })
               .max(by: { $0.startDate < $1.startDate }) {
            return existing.gameTitle
        }
        return cleaned
    }

    /// Renames every session of `oldTitle`, merging into an existing game when the new title
    /// matches one. Returns the title written, or nil when nothing changed.
    @discardableResult
    static func rename(_ oldTitle: String, to newTitle: String, in sessions: [PlaySession]) -> String? {
        guard let resolved = resolvedTitle(renaming: oldTitle, to: newTitle, in: sessions) else { return nil }
        let oldKey = GameTitleIndex.key(for: oldTitle)
        let newKey = GameTitleIndex.key(for: resolved)
        var changed = false
        for session in sessions where GameTitleIndex.key(for: session.gameTitle) == oldKey
            || (newKey != oldKey && GameTitleIndex.key(for: session.gameTitle) == newKey) {
            if session.gameTitle != resolved {
                session.gameTitle = resolved
                changed = true
            }
        }
        return changed ? resolved : nil
    }
}
