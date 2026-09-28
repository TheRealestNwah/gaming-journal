import Foundation

/// Editable copy of a session's fields, so the editor can be cancelled without touching the model.
struct SessionDraft: Equatable {
    var gameTitle = ""
    var platform = ""
    var startDate = Date.now
    var durationMinutes = 60
    var enjoyment: Int?
    var mood: Mood?
    var notes = ""
    var tagsText = ""
    var isMilestone = false
    var milestoneNote = ""

    init() {}

    init(session: PlaySession) {
        gameTitle = session.gameTitle
        platform = session.platform
        startDate = session.startDate
        durationMinutes = session.durationMinutes
        enjoyment = session.enjoyment
        mood = session.mood
        notes = session.notes
        tagsText = session.tags.joined(separator: ", ")
        isMilestone = session.isMilestone
        milestoneNote = session.milestoneNote
    }

    var trimmedTitle: String {
        gameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !trimmedTitle.isEmpty
    }

    var tags: [String] {
        TagParser.parse(tagsText)
    }

    /// Uses the index's existing spelling for the title so one game doesn't split into two.
    func makeSession(index: GameTitleIndex) -> PlaySession {
        let session = PlaySession(gameTitle: index.canonicalTitle(for: trimmedTitle))
        apply(to: session, index: index)
        return session
    }

    func apply(to session: PlaySession, index: GameTitleIndex) {
        session.gameTitle = index.canonicalTitle(for: trimmedTitle)
        session.platform = platform.trimmingCharacters(in: .whitespacesAndNewlines)
        session.startDate = startDate
        session.durationMinutes = max(0, durationMinutes)
        session.enjoyment = PlaySession.clampedEnjoyment(enjoyment)
        session.mood = mood
        session.notes = notes
        session.tags = tags
        session.isMilestone = isMilestone
        session.milestoneNote = isMilestone ? milestoneNote : ""
    }
}
