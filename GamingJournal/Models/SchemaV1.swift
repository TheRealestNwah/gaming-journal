import Foundation
import SwiftData

/// First shipped schema. Every stored property has a default and there are no
/// unique constraints so the store can be mirrored to CloudKit later.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [PlaySession.self]
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
}

typealias PlaySession = SchemaV1.PlaySession

extension PlaySession {
    var mood: Mood? {
        get { moodRaw.flatMap(Mood.init(rawValue:)) }
        set { moodRaw = newValue?.rawValue }
    }

    var endDate: Date {
        startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    /// "1h 30m", "45m", or "—" when no time was logged.
    var formattedDuration: String {
        PlaytimeFormatter.string(fromMinutes: durationMinutes)
    }

    static func clampedEnjoyment(_ value: Int?) -> Int? {
        value.map { min(5, max(1, $0)) }
    }
}

enum GamingJournalMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
