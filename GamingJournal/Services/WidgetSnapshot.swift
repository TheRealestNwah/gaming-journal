import Foundation
import WidgetKit

/// What the widgets show, written by the app to the shared App Group. The widget extension has a
/// mirror of this type (`GamingJournalWidgets/Snapshot.swift`); keep the two in step.
struct WidgetSnapshot: Codable, Equatable {
    #if FREE_TEAM
    static let appGroup = "group.com.gamingjournal.GamingJournal.free"
    #else
    static let appGroup = "group.com.gamingjournal.GamingJournal"
    #endif
    static let key = "widgetSnapshot"
    /// Opens a new page: in the journal a link names, or else the most recent one.
    static let writeURL = URL(string: "gamingjournal://write")!

    /// The journal a write link points at, if it names one.
    static func journalID(inWriteURL url: URL) -> UUID? {
        guard url.scheme == writeURL.scheme, url.host == writeURL.host else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "journal" }?.value
            .flatMap(UUID.init(uuidString:))
    }

    static func isWriteURL(_ url: URL) -> Bool {
        url.scheme == writeURL.scheme && url.host == writeURL.host
    }

    static func writeURL(for journalID: UUID) -> URL {
        var components = URLComponents(url: writeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "journal", value: journalID.uuidString)]
        return components.url!
    }

    /// The most recent entry across all journals.
    struct LatestEntry: Codable, Equatable {
        var journalID: UUID
        var characterName: String
        var heading: String
        /// Opening of the body, trimmed for a small widget.
        var excerpt: String
        var writtenAt: Date

        static let excerptLength = 160

        init(journalID: UUID, characterName: String, heading: String, excerpt: String, writtenAt: Date) {
            self.journalID = journalID
            self.characterName = characterName
            self.heading = heading
            self.excerpt = excerpt
            self.writtenAt = writtenAt
        }

        init(entry: Entry) {
            journalID = entry.journal?.id ?? UUID()
            characterName = entry.journal?.characterName ?? ""
            heading = entry.heading()
            let body = entry.body.replacingOccurrences(of: "\n", with: " ")
            excerpt = body.count > Self.excerptLength
                ? String(body.prefix(Self.excerptLength)).trimmingCharacters(in: .whitespaces) + "…"
                : body
            writtenAt = entry.writtenAt
        }
    }

    var generatedAt: Date
    var latestEntry: LatestEntry?

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> WidgetSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(WidgetSnapshot.self, from: data)
    }

    /// Stores the snapshot for the widgets and asks them to refresh, skipping both when nothing
    /// they display has changed.
    func publish(to defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) {
        guard let defaults, let data = try? encoded() else { return }
        if let old = defaults.data(forKey: Self.key).flatMap({ try? Self.decode($0) }), old.sameContent(as: self) {
            return
        }
        defaults.set(data, forKey: Self.key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Equal apart from `generatedAt`.
    func sameContent(as other: WidgetSnapshot) -> Bool {
        var copy = other
        copy.generatedAt = generatedAt
        return copy == self
    }
}
