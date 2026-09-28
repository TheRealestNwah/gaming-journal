import Foundation

/// Lookup over past sessions used by the editor: title suggestions, the canonical spelling of a
/// title, and the platform last used for a game. Titles are compared case- and
/// whitespace-insensitively.
struct GameTitleIndex {
    struct Entry {
        var title: String
        var platform: String
        var date: Date
    }

    private struct GameInfo {
        var title: String
        var lastPlayed: Date
        var lastPlatform: String
        var sessionCount: Int
    }

    private var games: [String: GameInfo] = [:]

    init(entries: [Entry]) {
        for entry in entries {
            let key = Self.key(for: entry.title)
            guard !key.isEmpty else { continue }
            if var info = games[key] {
                info.sessionCount += 1
                if entry.date >= info.lastPlayed {
                    info.lastPlayed = entry.date
                    if !entry.platform.isEmpty { info.lastPlatform = entry.platform }
                } else if info.lastPlatform.isEmpty {
                    info.lastPlatform = entry.platform
                }
                games[key] = info
            } else {
                games[key] = GameInfo(
                    title: entry.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    lastPlayed: entry.date,
                    lastPlatform: entry.platform,
                    sessionCount: 1
                )
            }
        }
    }

    init(sessions: [PlaySession]) {
        self.init(entries: sessions.map {
            Entry(title: $0.gameTitle, platform: $0.platform, date: $0.startDate)
        })
    }

    /// Normalised comparison key: lowercased, trimmed, inner whitespace collapsed.
    static func key(for title: String) -> String {
        title.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Distinct titles, most recently played first.
    var recentTitles: [String] {
        games.values.sorted { $0.lastPlayed > $1.lastPlayed }.map(\.title)
    }

    /// Titles containing the query, prefix matches first, then most recent. An empty query
    /// returns the most recent titles. An exact match of the query itself is left out.
    func suggestions(for query: String, limit: Int = 5) -> [String] {
        let needle = Self.key(for: query)
        guard !needle.isEmpty else { return Array(recentTitles.prefix(limit)) }
        return games
            .filter { key, _ in key != needle && key.contains(needle) }
            .sorted { lhs, rhs in
                let lhsPrefix = lhs.key.hasPrefix(needle)
                let rhsPrefix = rhs.key.hasPrefix(needle)
                if lhsPrefix != rhsPrefix { return lhsPrefix }
                return lhs.value.lastPlayed > rhs.value.lastPlayed
            }
            .prefix(limit)
            .map(\.value.title)
    }

    /// The existing spelling of a title typed differently ("hades " → "Hades"), or the trimmed
    /// input when the game is new.
    func canonicalTitle(for input: String) -> String {
        games[Self.key(for: input)]?.title
            ?? input.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    func lastPlatform(for title: String) -> String? {
        guard let platform = games[Self.key(for: title)]?.lastPlatform, !platform.isEmpty else {
            return nil
        }
        return platform
    }

    func sessionCount(for title: String) -> Int {
        games[Self.key(for: title)]?.sessionCount ?? 0
    }
}
