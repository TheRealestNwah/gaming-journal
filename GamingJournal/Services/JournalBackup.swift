import Foundation
import SwiftData

/// Full JSON backup of every journal. `version` lets later app versions read older files and
/// refuse newer ones they don't understand. Version 3 is the one-journal-per-character format;
/// versions 1 and 2 held play sessions and notebooks, which the app no longer has.
struct JournalBackup: Codable, Equatable {
    static let currentVersion = 3

    struct Photo: Codable, Equatable {
        var id: UUID
        var imageData: Data
        var thumbnailData: Data?
        var sortIndex: Int
        var createdAt: Date
    }

    struct EntryRecord: Codable, Equatable {
        var id: UUID
        var body: String
        var inGameDate: String
        var writtenAt: Date
        var createdAt: Date
        var updatedAt: Date
        var photos: [Photo]
    }

    struct JournalRecord: Codable, Equatable {
        var id: UUID
        var characterName: String
        var epithet: String
        var gameTitle: String
        var coverStyle: String
        var createdAt: Date
        var updatedAt: Date
        var entries: [EntryRecord]
    }

    enum BackupError: Error, Equatable, LocalizedError {
        case unsupportedVersion(Int)
        case olderFormat
        case unreadable

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                "This backup was made by a newer version of Hearthbound (format \(version)). Update the app to import it."
            case .olderFormat:
                "This backup is from before Hearthbound kept one journal per character, so it can't be imported."
            case .unreadable:
                "This file isn't a Hearthbound backup."
            }
        }
    }

    var version: Int
    var exportedAt: Date
    var journals: [JournalRecord]

    init(version: Int = JournalBackup.currentVersion, exportedAt: Date = .now, journals: [JournalRecord]) {
        self.version = version
        self.exportedAt = exportedAt
        self.journals = journals
    }

    init(exporting journals: [Journal], exportedAt: Date = .now) {
        self.init(
            exportedAt: exportedAt,
            journals: journals.sorted { $0.createdAt < $1.createdAt }.map(JournalRecord.init(journal:))
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
        guard probe.version == currentVersion else {
            throw BackupError.olderFormat
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
}

extension JournalBackup.JournalRecord {
    init(journal: Journal) {
        id = journal.id
        characterName = journal.characterName
        epithet = journal.epithet
        gameTitle = journal.gameTitle
        coverStyle = journal.coverStyleRaw
        createdAt = journal.createdAt
        updatedAt = journal.updatedAt
        entries = journal.story.map(JournalBackup.EntryRecord.init(entry:))
    }

    /// A new, unsaved journal with the same values and ID, without its entries.
    func makeJournal() -> Journal {
        let journal = Journal(
            id: id,
            characterName: characterName,
            epithet: epithet,
            gameTitle: gameTitle,
            coverStyle: CoverStyle(rawValue: coverStyle) ?? .ember,
            createdAt: createdAt
        )
        journal.updatedAt = updatedAt
        return journal
    }
}

extension JournalBackup.EntryRecord {
    init(entry: Entry) {
        id = entry.id
        body = entry.body
        inGameDate = entry.inGameDate
        writtenAt = entry.writtenAt
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
        photos = entry.sortedPhotos.compactMap { photo -> JournalBackup.Photo? in
            // A photo missing its full image (not downloaded yet, or damaged) keeps its thumbnail.
            guard let image = photo.imageData ?? photo.thumbnailData else { return nil }
            return JournalBackup.Photo(
                id: photo.id,
                imageData: image,
                thumbnailData: photo.thumbnailData,
                sortIndex: photo.sortIndex,
                createdAt: photo.createdAt
            )
        }
    }

    /// A new, unsaved entry with the same values, ID and photos.
    func makeEntry() -> Entry {
        let entry = Entry(id: id, body: body, inGameDate: inGameDate, writtenAt: writtenAt, createdAt: createdAt)
        entry.updatedAt = updatedAt
        entry.photos = photos.map { photo in
            EntryPhoto(
                id: photo.id,
                imageData: photo.imageData,
                thumbnailData: photo.thumbnailData,
                sortIndex: photo.sortIndex,
                createdAt: photo.createdAt
            )
        }
        return entry
    }
}

/// Merges a backup into the store without duplicating anything already there.
enum JournalImporter {
    struct Report: Equatable {
        var journalsAdded = 0
        var entriesAdded = 0
        /// Entries whose IDs were already present (or repeated in the file).
        var skipped = 0

        var summary: String {
            var parts: [String] = []
            if journalsAdded > 0 { parts.append("\(journalsAdded) journal\(journalsAdded == 1 ? "" : "s")") }
            if entriesAdded > 0 { parts.append("\(entriesAdded) entr\(entriesAdded == 1 ? "y" : "ies")") }
            let added = parts.isEmpty ? "Nothing new to add." : "Added " + parts.joined(separator: ", ") + "."
            return skipped > 0 ? added + " Skipped \(skipped) already in your journals." : added
        }
    }

    /// Adds new journals whole; for journals already present, adds just the entries that are new.
    @MainActor
    static func importBackup(_ backup: JournalBackup, into context: ModelContext) throws -> Report {
        var report = Report()
        let existing = try context.fetch(FetchDescriptor<Journal>())
        var journalsByID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var knownEntryIDs = Set(try context.fetch(FetchDescriptor<Entry>()).map(\.id))

        for record in backup.journals {
            let journal: Journal
            if let present = journalsByID[record.id] {
                journal = present
            } else {
                journal = record.makeJournal()
                context.insert(journal)
                journalsByID[record.id] = journal
                report.journalsAdded += 1
            }
            for entryRecord in record.entries {
                guard knownEntryIDs.insert(entryRecord.id).inserted else {
                    report.skipped += 1
                    continue
                }
                let entry = entryRecord.makeEntry()
                context.insert(entry)
                entry.journal = journal
                report.entriesAdded += 1
                // The shelf is ordered by this, so a journal that gained entries moves up.
                if entry.updatedAt > journal.updatedAt {
                    journal.updatedAt = entry.updatedAt
                }
            }
        }
        try context.save()
        return report
    }
}
