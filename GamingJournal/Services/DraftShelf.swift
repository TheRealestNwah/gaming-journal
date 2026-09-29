import Foundation

/// Keeps an unfinished new entry per notebook, so closing the editor by accident or the app being
/// killed doesn't lose it. Photos aren't kept: they're large, and quick to pick again.
struct DraftShelf {
    /// The words and details of an unfinished entry.
    struct Saved: Codable, Equatable {
        var title: String
        var body: String
        var writtenAt: Date
        var inGameDate: String
        var place: String
        var quest: String
        var isTurningPoint: Bool
        var authorID: UUID?
        var chapterID: UUID?
        var emotions: [FeltEmotion]
        var bonds: [Bond]
        var savedAt: Date

        init(_ draft: EntryDraft, savedAt: Date = .now) {
            title = draft.title
            body = draft.body
            writtenAt = draft.writtenAt
            inGameDate = draft.inGameDate
            place = draft.place
            quest = draft.quest
            isTurningPoint = draft.isTurningPoint
            authorID = draft.authorID
            chapterID = draft.chapterID
            emotions = draft.emotions
            bonds = draft.bonds
            self.savedAt = savedAt
        }

        var draft: EntryDraft {
            var draft = EntryDraft(authorID: authorID, chapterID: chapterID)
            draft.title = title
            draft.body = body
            draft.writtenAt = writtenAt
            draft.inGameDate = inGameDate
            draft.place = place
            draft.quest = quest
            draft.isTurningPoint = isTurningPoint
            draft.emotions = emotions
            draft.bonds = bonds
            return draft
        }

        /// "Title" or the opening words, for the offer to continue.
        var preview: String {
            let text = title.isEmpty ? body : title
            let flat = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            return flat.count > 60 ? String(flat.prefix(60)) + "…" : flat
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func key(for notebookID: UUID) -> String {
        "draft.\(notebookID.uuidString)"
    }

    func saved(for notebookID: UUID) -> Saved? {
        defaults.data(forKey: Self.key(for: notebookID)).flatMap { try? JSONDecoder().decode(Saved.self, from: $0) }
    }

    /// Keeps the draft if there's anything worth keeping, otherwise forgets it.
    func keep(_ draft: EntryDraft, for notebookID: UUID, now: Date = .now) {
        guard draft.isValid, let data = try? JSONEncoder().encode(Saved(draft, savedAt: now)) else {
            discard(for: notebookID)
            return
        }
        defaults.set(data, forKey: Self.key(for: notebookID))
    }

    func discard(for notebookID: UUID) {
        defaults.removeObject(forKey: Self.key(for: notebookID))
    }
}
