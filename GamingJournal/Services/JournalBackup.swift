import Foundation

/// Full JSON backup of the journal. `version` lets later app versions read older files and refuse
/// newer ones they don't understand.
struct JournalBackup: Codable, Equatable {
    static let currentVersion = 1

    struct Photo: Codable, Equatable {
        var id: UUID
        var imageData: Data
        var thumbnailData: Data?
        var sortIndex: Int
        var createdAt: Date
    }

    struct Session: Codable, Equatable {
        var id: UUID
        var gameTitle: String
        var platform: String
        var startDate: Date
        var durationMinutes: Int
        var enjoyment: Int?
        var mood: String?
        var notes: String
        var tags: [String]
        var isMilestone: Bool
        var milestoneNote: String
        var createdAt: Date
        var photos: [Photo]
    }

    enum BackupError: Error, Equatable, LocalizedError {
        case unsupportedVersion(Int)
        case unreadable

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                "This backup was made by a newer version of Gaming Journal (format \(version)). Update the app to import it."
            case .unreadable:
                "This file isn't a Gaming Journal backup."
            }
        }
    }

    var version: Int
    var exportedAt: Date
    var sessions: [Session]

    init(version: Int = JournalBackup.currentVersion, exportedAt: Date = .now, sessions: [Session]) {
        self.version = version
        self.exportedAt = exportedAt
        self.sessions = sessions
    }

    init(exporting sessions: [PlaySession], exportedAt: Date = .now) {
        self.init(
            exportedAt: exportedAt,
            sessions: sessions
                .sorted { $0.startDate < $1.startDate }
                .map(Session.init(session:))
        )
    }

    // MARK: Encoding

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.dateFormatter(fractional: true).string(from: date))
        }
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> JournalBackup {
        struct VersionProbe: Decodable { var version: Int }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = dateFormatter(fractional: true).date(from: text)
                    ?? dateFormatter(fractional: false).date(from: text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(text)")
            }
            return date
        }
        guard let probe = try? decoder.decode(VersionProbe.self, from: data) else {
            throw BackupError.unreadable
        }
        guard probe.version <= currentVersion else {
            throw BackupError.unsupportedVersion(probe.version)
        }
        do {
            return try decoder.decode(JournalBackup.self, from: data)
        } catch {
            throw BackupError.unreadable
        }
    }

    private static func dateFormatter(fractional: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = fractional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter
    }

    // MARK: Merging

    struct MergePlan: Equatable {
        /// Sessions to add, in backup order.
        var newSessions: [Session]
        /// Sessions skipped because their ID is already in the journal (or repeated in the file).
        var skippedCount: Int
    }

    /// Picks the sessions whose IDs aren't already present, so importing the same file twice
    /// never duplicates anything.
    func mergePlan(existingIDs: Set<UUID>) -> MergePlan {
        var seen = existingIDs
        var fresh: [Session] = []
        for session in sessions where seen.insert(session.id).inserted {
            fresh.append(session)
        }
        return MergePlan(newSessions: fresh, skippedCount: sessions.count - fresh.count)
    }
}

extension JournalBackup.Session {
    init(session: PlaySession) {
        id = session.id
        gameTitle = session.gameTitle
        platform = session.platform
        startDate = session.startDate
        durationMinutes = session.durationMinutes
        enjoyment = session.enjoyment
        mood = session.moodRaw
        notes = session.notes
        tags = session.tags
        isMilestone = session.isMilestone
        milestoneNote = session.milestoneNote
        createdAt = session.createdAt
        photos = session.sortedPhotos.compactMap { photo -> JournalBackup.Photo? in
            guard let image = photo.imageData else { return nil }
            return JournalBackup.Photo(
                id: photo.id,
                imageData: image,
                thumbnailData: photo.thumbnailData,
                sortIndex: photo.sortIndex,
                createdAt: photo.createdAt
            )
        }
    }

    /// A new, unsaved model with the same values and ID.
    func makeSession() -> PlaySession {
        let session = PlaySession(
            id: id,
            gameTitle: gameTitle,
            platform: platform,
            startDate: startDate,
            durationMinutes: durationMinutes,
            enjoyment: enjoyment,
            notes: notes,
            tags: tags,
            isMilestone: isMilestone,
            milestoneNote: milestoneNote,
            createdAt: createdAt
        )
        session.moodRaw = mood
        session.photos = photos.map { photo in
            SessionPhoto(
                id: photo.id,
                imageData: photo.imageData,
                thumbnailData: photo.thumbnailData,
                sortIndex: photo.sortIndex,
                createdAt: photo.createdAt
            )
        }
        return session
    }
}
