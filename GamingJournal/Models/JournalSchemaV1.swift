import Foundation
import SwiftData

/// The notebook app's first schema: playthrough notebooks, their party and in-character entries,
/// plus play sessions. Every property has a default, there are no unique constraints and all
/// relationships are optional so the store can be mirrored to CloudKit.
enum JournalSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Notebook.self, PartyMember.self, Entry.self, EntryPhoto.self, PlaySession.self, SessionPhoto.self]
    }

    /// One playthrough of one game.
    @Model
    final class Notebook {
        var id: UUID = UUID()
        var title: String = ""
        var gameTitle: String = ""
        var platform: String = ""
        /// Raw value of `CoverStyle`.
        var coverStyleRaw: String = CoverStyle.ember.rawValue
        /// Raw value of `NotebookStatus`.
        var statusRaw: String = NotebookStatus.ongoing.rawValue
        var startedAt: Date = Date()
        var summary: String = ""
        var createdAt: Date = Date()
        /// Bumped whenever the notebook or one of its entries changes; orders the Library.
        var updatedAt: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \PartyMember.notebook)
        var members: [PartyMember]? = []
        @Relationship(deleteRule: .cascade, inverse: \Entry.notebook)
        var entries: [Entry]? = []
        @Relationship(deleteRule: .nullify, inverse: \PlaySession.notebook)
        var sessions: [PlaySession]? = []

        init(
            id: UUID = UUID(),
            title: String,
            gameTitle: String = "",
            platform: String = "",
            coverStyle: CoverStyle = .ember,
            status: NotebookStatus = .ongoing,
            startedAt: Date = .now,
            summary: String = "",
            createdAt: Date = .now
        ) {
            self.id = id
            self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            self.gameTitle = gameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            self.platform = platform.trimmingCharacters(in: .whitespacesAndNewlines)
            self.coverStyleRaw = coverStyle.rawValue
            self.statusRaw = status.rawValue
            self.startedAt = startedAt
            self.summary = summary
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    /// A character in a notebook's party. Named `PartyMember` because `Character` is a Swift type.
    @Model
    final class PartyMember {
        var id: UUID = UUID()
        var name: String = ""
        /// Role or class, e.g. "Ranger" or "Paragon Shepard".
        var role: String = ""
        var backstory: String = ""
        /// Raw value of `Sigil`.
        var sigilRaw: String = Sigil.ember.rawValue
        @Attribute(.externalStorage) var portraitData: Data?
        /// Position in the party.
        var sortIndex: Int = 0
        /// Left the party (died, parted ways) but their entries stay.
        var isRetired: Bool = false
        var createdAt: Date = Date()
        var notebook: Notebook?
        @Relationship(deleteRule: .nullify, inverse: \Entry.author)
        var entries: [Entry]? = []

        init(
            id: UUID = UUID(),
            name: String,
            role: String = "",
            backstory: String = "",
            sigil: Sigil = .ember,
            sortIndex: Int = 0,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            self.role = role.trimmingCharacters(in: .whitespacesAndNewlines)
            self.backstory = backstory
            self.sigilRaw = sigil.rawValue
            self.sortIndex = sortIndex
            self.createdAt = createdAt
        }
    }

    /// A journal entry written in character.
    @Model
    final class Entry {
        var id: UUID = UUID()
        var title: String = ""
        var body: String = ""
        /// Real-world date the entry is filed under.
        var writtenAt: Date = Date()
        /// Free-text date inside the game world, e.g. "4th of Last Seed".
        var inGameDate: String = ""
        var place: String = ""
        var quest: String = ""
        var isTurningPoint: Bool = false
        /// JSON-encoded `[FeltEmotion]`; use `emotions`.
        var emotionsData: Data = Data()
        /// JSON-encoded `[Bond]`; use `bonds`.
        var bondsData: Data = Data()
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var notebook: Notebook?
        var author: PartyMember?
        @Relationship(deleteRule: .cascade, inverse: \EntryPhoto.entry)
        var photos: [EntryPhoto]? = []

        init(
            id: UUID = UUID(),
            title: String = "",
            body: String = "",
            writtenAt: Date = .now,
            inGameDate: String = "",
            place: String = "",
            quest: String = "",
            isTurningPoint: Bool = false,
            emotions: [FeltEmotion] = [],
            bonds: [Bond] = [],
            createdAt: Date = .now
        ) {
            self.id = id
            self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            self.body = body
            self.writtenAt = writtenAt
            self.inGameDate = inGameDate.trimmingCharacters(in: .whitespacesAndNewlines)
            self.place = place.trimmingCharacters(in: .whitespacesAndNewlines)
            self.quest = quest.trimmingCharacters(in: .whitespacesAndNewlines)
            self.isTurningPoint = isTurningPoint
            self.emotionsData = EntryCoding.encode(FeltEmotion.normalized(emotions))
            self.bondsData = EntryCoding.encode(bonds.map { $0.clamped() })
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    /// A screenshot or sketch attached to an entry. Image bytes live outside the store file.
    @Model
    final class EntryPhoto {
        var id: UUID = UUID()
        @Attribute(.externalStorage) var imageData: Data?
        @Attribute(.externalStorage) var thumbnailData: Data?
        var sortIndex: Int = 0
        var createdAt: Date = Date()
        var entry: Entry?

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
        /// The playthrough this session belongs to, if any.
        var notebook: Notebook?

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
