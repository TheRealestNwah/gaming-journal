import Foundation

/// A photo in the editor: either already stored on the session (same id) or newly picked.
struct DraftPhoto: Identifiable, Equatable {
    var id = UUID()
    var imageData: Data
    var thumbnailData: Data
}

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
    var photos: [DraftPhoto] = []

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
        photos = session.sortedPhotos.compactMap { photo -> DraftPhoto? in
            guard let image = photo.imageData else { return nil }
            return DraftPhoto(id: photo.id, imageData: image, thumbnailData: photo.thumbnailData ?? image)
        }
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
        applyPhotos(to: session)
    }

    /// Deletes photos the user removed, adds new ones and stores the draft's order.
    private func applyPhotos(to session: PlaySession) {
        let existing = session.photos ?? []
        let keptIDs = Set(photos.map(\.id))
        let removed = existing.filter { !keptIDs.contains($0.id) }
        var remaining = existing.filter { keptIDs.contains($0.id) }
        for photo in removed {
            if let context = photo.modelContext {
                context.delete(photo)
            }
        }
        for (index, draftPhoto) in photos.enumerated() {
            if let photo = remaining.first(where: { $0.id == draftPhoto.id }) {
                photo.sortIndex = index
            } else {
                let photo = SessionPhoto(
                    id: draftPhoto.id,
                    imageData: draftPhoto.imageData,
                    thumbnailData: draftPhoto.thumbnailData,
                    sortIndex: index
                )
                remaining.append(photo)
            }
        }
        session.photos = remaining
    }
}
