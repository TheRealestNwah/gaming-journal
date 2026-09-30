import Foundation
import SwiftData

/// V1 plus a place line under each entry's date (#147). Everything else is unchanged, so the
/// move from V1 is a lightweight migration. The same CloudKit rules apply: every property has a
/// default, no unique constraints, optional relationships.
enum HearthboundSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Journal.self, Entry.self, EntryPhoto.self]
    }

    /// The journal a character keeps through one game.
    @Model
    final class Journal {
        var id: UUID = UUID()
        var characterName: String = ""
        /// Race, class or title, e.g. "Nord Dragonborn".
        var epithet: String = ""
        var gameTitle: String = ""
        /// Raw value of `CoverStyle`.
        var coverStyleRaw: String = CoverStyle.ember.rawValue
        var createdAt: Date = Date()
        /// Bumped whenever the journal or one of its entries changes; orders the shelf.
        var updatedAt: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \Entry.journal)
        var entries: [Entry]? = []

        init(
            id: UUID = UUID(),
            characterName: String,
            epithet: String = "",
            gameTitle: String = "",
            coverStyle: CoverStyle = .ember,
            createdAt: Date = .now
        ) {
            self.id = id
            self.characterName = characterName.trimmingCharacters(in: .whitespacesAndNewlines)
            self.epithet = epithet.trimmingCharacters(in: .whitespacesAndNewlines)
            self.gameTitle = gameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            self.coverStyleRaw = coverStyle.rawValue
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    /// One dated entry, written in the character's voice.
    @Model
    final class Entry {
        var id: UUID = UUID()
        var body: String = ""
        /// Free-text date inside the game world, e.g. "17th of Last Seed, 4E 201".
        var inGameDate: String = ""
        /// Where the character was, e.g. "Whiterun". Empty when not given.
        var place: String = ""
        /// Real-world date the entry is filed under.
        var writtenAt: Date = Date()
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var journal: Journal?
        @Relationship(deleteRule: .cascade, inverse: \EntryPhoto.entry)
        var photos: [EntryPhoto]? = []

        init(
            id: UUID = UUID(),
            body: String = "",
            inGameDate: String = "",
            place: String = "",
            writtenAt: Date = .now,
            createdAt: Date = .now
        ) {
            self.id = id
            self.body = body
            self.inGameDate = inGameDate.trimmingCharacters(in: .whitespacesAndNewlines)
            self.place = place.trimmingCharacters(in: .whitespacesAndNewlines)
            self.writtenAt = writtenAt
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    /// A screenshot or sketch pasted into an entry. Image bytes live outside the store file.
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
}
