import Foundation
import SwiftData

typealias PlaySession = SchemaV2.PlaySession
typealias SessionPhoto = SchemaV2.SessionPhoto

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

    /// Photos in strip order.
    var sortedPhotos: [SessionPhoto] {
        (photos ?? []).sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }
    }

    static func clampedEnjoyment(_ value: Int?) -> Int? {
        value.map { min(5, max(1, $0)) }
    }
}

enum GamingJournalMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}
