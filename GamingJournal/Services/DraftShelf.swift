import Foundation

/// Keeps an unfinished new entry per journal, so closing the writer by accident or the app being
/// killed doesn't lose it. Photos aren't kept: they're large, and quick to pick again.
struct DraftShelf {
    /// The words and date of an unfinished entry.
    struct Saved: Codable, Equatable {
        var body: String
        var inGameDate: String
        /// Optional so pages kept before places existed still read.
        var place: String?
        var writtenAt: Date
        var savedAt: Date

        init(_ draft: EntryDraft, savedAt: Date = .now) {
            body = draft.body
            inGameDate = draft.inGameDate
            place = draft.place
            writtenAt = draft.writtenAt
            self.savedAt = savedAt
        }

        var draft: EntryDraft {
            EntryDraft(body: body, inGameDate: inGameDate, place: place ?? "", writtenAt: writtenAt)
        }

        /// The opening words, for the offer to continue.
        var preview: String {
            let flat = body.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            return flat.count > 60 ? String(flat.prefix(60)) + "…" : flat
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func key(for journalID: UUID) -> String {
        "draft.\(journalID.uuidString)"
    }

    func saved(for journalID: UUID) -> Saved? {
        defaults.data(forKey: Self.key(for: journalID)).flatMap { try? JSONDecoder().decode(Saved.self, from: $0) }
    }

    /// Keeps the draft if it has any words, otherwise forgets it.
    func keep(_ draft: EntryDraft, for journalID: UUID, now: Date = .now) {
        guard !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = try? JSONEncoder().encode(Saved(draft, savedAt: now))
        else {
            discard(for: journalID)
            return
        }
        defaults.set(data, forKey: Self.key(for: journalID))
    }

    func discard(for journalID: UUID) {
        defaults.removeObject(forKey: Self.key(for: journalID))
    }
}
