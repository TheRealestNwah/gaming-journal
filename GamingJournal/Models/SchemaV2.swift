import Foundation
import SwiftData

/// Adds photos to sessions. Same CloudKit rules as V1: defaults everywhere, optional relationships.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [PlaySession.self, SessionPhoto.self]
    }

    /// One sitting with one game.
    @Model
    final class PlaySession {
        var id: UUID = UUID()
        var gameTitle: String = ""
        var platform: String = ""
        var startDate: Date = Date()
        var durationMinutes: Int = 0
        /// 1–5 stars, or nil when unrated.
        var enjoyment: Int?
        /// Raw value of `Mood`; stored as a string so new moods never break old rows.
        var moodRaw: String?
        var notes: String = ""
        var tags: [String] = []
        /// Marks a notable session: finished the game, beat a boss, got a trophy…
        var isMilestone: Bool = false
        var milestoneNote: String = ""
        var createdAt: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \SessionPhoto.session)
        var photos: [SessionPhoto]? = []

        init(
            id: UUID = UUID(),
            gameTitle: String,
            platform: String = "",
            startDate: Date = .now,
            durationMinutes: Int = 0,
            enjoyment: Int? = nil,
            mood: Mood? = nil,
            notes: String = "",
            tags: [String] = [],
            isMilestone: Bool = false,
            milestoneNote: String = "",
            createdAt: Date = .now
        ) {
            self.id = id
            self.gameTitle = gameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            self.platform = platform.trimmingCharacters(in: .whitespacesAndNewlines)
            self.startDate = startDate
            self.durationMinutes = max(0, durationMinutes)
            self.enjoyment = PlaySession.clampedEnjoyment(enjoyment)
            self.moodRaw = mood?.rawValue
            self.notes = notes
            self.tags = TagParser.normalize(tags)
            self.isMilestone = isMilestone
            self.milestoneNote = milestoneNote
            self.createdAt = createdAt
        }
    }

    /// A screenshot or photo attached to a session. Image bytes live outside the store file.
    @Model
    final class SessionPhoto {
        var id: UUID = UUID()
        @Attribute(.externalStorage) var imageData: Data?
        @Attribute(.externalStorage) var thumbnailData: Data?
        /// Position in the session's strip.
        var sortIndex: Int = 0
        var createdAt: Date = Date()
        var session: PlaySession?

        init(
            id: UUID = UUID(),
            imageData: Data?,
            thumbnailData: Data?,
            sortIndex: Int = 0,
            createdAt: Date = .now
        ) {
            self.id = id
            self.imageData = imageData
            self.thumbnailData = thumbnailData
            self.sortIndex = sortIndex
            self.createdAt = createdAt
        }
    }
}
