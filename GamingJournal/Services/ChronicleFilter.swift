import Foundation

/// Search and filters for a notebook's chronicle. Text and place comparisons ignore case and
/// extra spaces.
struct ChronicleFilter: Equatable {
    var searchText = ""
    var memberID: UUID?
    var emotion: Emotion?
    var place: String?
    var turningPointsOnly = false

    var hasFacets: Bool {
        memberID != nil || emotion != nil || place != nil || turningPointsOnly
    }

    var isActive: Bool {
        hasFacets || !Self.normalize(searchText).isEmpty
    }

    mutating func clearFacets() {
        memberID = nil
        emotion = nil
        place = nil
        turningPointsOnly = false
    }

    func matches(_ entry: Entry) -> Bool {
        if turningPointsOnly && !entry.isTurningPoint { return false }
        if let memberID, entry.author?.id != memberID { return false }
        if let emotion, !entry.emotions.contains(where: { $0.emotion == emotion }) { return false }
        if let place, Self.normalize(entry.place) != Self.normalize(place) { return false }

        let words = Self.normalize(searchText).split(separator: " ")
        guard !words.isEmpty else { return true }
        let haystack = Self.normalize(
            [entry.title, entry.body, entry.place, entry.quest, entry.inGameDate, entry.author?.name ?? ""]
                .joined(separator: " ")
        )
        return words.allSatisfy { haystack.contains($0) }
    }

    func apply(to entries: [Entry]) -> [Entry] {
        isActive ? entries.filter(matches) : entries
    }

    static func normalize(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

/// Places and quests gathered from a notebook's entries.
enum Atlas {
    struct Item: Identifiable, Equatable {
        /// Most recent spelling.
        var name: String
        var entryCount: Int
        var firstSeen: Date
        var lastSeen: Date
        /// Names of the party members who wrote about it, in first-seen order.
        var writers: [String]

        var id: String { ChronicleFilter.normalize(name) }
    }

    static func places(in entries: [Entry]) -> [Item] {
        gather(entries, by: \.place)
    }

    static func quests(in entries: [Entry]) -> [Item] {
        gather(entries, by: \.quest)
    }

    /// Items most recently visited first.
    private static func gather(_ entries: [Entry], by key: KeyPath<Entry, String>) -> [Item] {
        var items: [String: Item] = [:]
        for entry in entries.sorted(by: { $0.writtenAt < $1.writtenAt }) {
            let name = entry[keyPath: key].split(whereSeparator: \.isWhitespace).joined(separator: " ")
            let normalized = ChronicleFilter.normalize(name)
            guard !normalized.isEmpty else { continue }
            var item = items[normalized]
                ?? Item(name: name, entryCount: 0, firstSeen: entry.writtenAt, lastSeen: entry.writtenAt, writers: [])
            item.name = name
            item.entryCount += 1
            item.lastSeen = entry.writtenAt
            if let writer = entry.author?.name, !writer.isEmpty, !item.writers.contains(writer) {
                item.writers.append(writer)
            }
            items[normalized] = item
        }
        return items.values.sorted { $0.lastSeen != $1.lastSeen ? $0.lastSeen > $1.lastSeen : $0.name < $1.name }
    }

    /// Autocomplete for the editor: names containing the query, prefix matches first, then most
    /// recent. The exact current value is left out.
    static func suggestions(_ items: [Item], for query: String, limit: Int = 5) -> [String] {
        let needle = ChronicleFilter.normalize(query)
        guard !needle.isEmpty else { return Array(items.prefix(limit).map(\.name)) }
        return items
            .filter { $0.id != needle && $0.id.contains(needle) }
            .sorted { lhs, rhs in
                let lhsPrefix = lhs.id.hasPrefix(needle)
                let rhsPrefix = rhs.id.hasPrefix(needle)
                if lhsPrefix != rhsPrefix { return lhsPrefix }
                return lhs.lastSeen > rhs.lastSeen
            }
            .prefix(limit)
            .map(\.name)
    }
}
