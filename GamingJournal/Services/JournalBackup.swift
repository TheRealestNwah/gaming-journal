import Foundation
import SwiftData

/// Full JSON backup of the journal. `version` lets later app versions read older files and refuse
/// newer ones they don't understand. Version 1 held sessions only; version 2 adds notebooks with
/// their party and entries, and links sessions to notebooks.
struct JournalBackup: Codable, Equatable {
    static let currentVersion = 2

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
        /// Added in version 2.
        var notebookID: UUID?
    }

    struct Member: Codable, Equatable {
        var id: UUID
        var name: String
        var role: String
        var backstory: String
        var sigil: String
        var portraitData: Data?
        var sortIndex: Int
        var isRetired: Bool
        var createdAt: Date
    }

    struct JournalEntry: Codable, Equatable {
        var id: UUID
        var title: String
        var body: String
        var writtenAt: Date
        var inGameDate: String
        var place: String
        var quest: String
        var isTurningPoint: Bool
        var emotions: [FeltEmotion]
        var bonds: [Bond]
        var authorID: UUID?
        var createdAt: Date
        var updatedAt: Date
        var photos: [Photo]
    }

    struct NotebookRecord: Codable, Equatable {
        var id: UUID
        var title: String
        var gameTitle: String
        var platform: String
        var coverStyle: String
        var status: String
        var startedAt: Date
        var summary: String
        var createdAt: Date
        var updatedAt: Date
        var members: [Member]
        var entries: [JournalEntry]
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
    /// Missing from version 1 files.
    var notebooks: [NotebookRecord]?

    init(
        version: Int = JournalBackup.currentVersion,
        exportedAt: Date = .now,
        sessions: [Session],
        notebooks: [NotebookRecord]? = nil
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.sessions = sessions
        self.notebooks = notebooks
    }

    init(exporting sessions: [PlaySession], notebooks: [Notebook] = [], exportedAt: Date = .now) {
        self.init(
            exportedAt: exportedAt,
            sessions: sessions
                .sorted { $0.startDate < $1.startDate }
                .map(Session.init(session:)),
            notebooks: notebooks
                .sorted { $0.createdAt < $1.createdAt }
                .map(NotebookRecord.init(notebook:))
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
        notebookID = session.notebook?.id
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

extension JournalBackup.NotebookRecord {
    init(notebook: Notebook) {
        id = notebook.id
        title = notebook.title
        gameTitle = notebook.gameTitle
        platform = notebook.platform
        coverStyle = notebook.coverStyleRaw
        status = notebook.statusRaw
        startedAt = notebook.startedAt
        summary = notebook.summary
        createdAt = notebook.createdAt
        updatedAt = notebook.updatedAt
        members = notebook.party.map(JournalBackup.Member.init(member:))
        entries = (notebook.entries ?? [])
            .sorted { ($0.writtenAt, $0.createdAt) < ($1.writtenAt, $1.createdAt) }
            .map(JournalBackup.JournalEntry.init(entry:))
    }

    /// A new, unsaved notebook with its party and entries, keeping every ID.
    func makeNotebook() -> Notebook {
        let notebook = Notebook(
            id: id,
            title: title,
            gameTitle: gameTitle,
            platform: platform,
            startedAt: startedAt,
            summary: summary,
            createdAt: createdAt
        )
        notebook.coverStyleRaw = coverStyle
        notebook.statusRaw = status
        notebook.updatedAt = updatedAt
        let madeMembers = members.map { $0.makeMember() }
        notebook.members = madeMembers
        notebook.entries = entries.map { $0.makeEntry(members: madeMembers) }
        return notebook
    }
}

extension JournalBackup.Member {
    init(member: PartyMember) {
        id = member.id
        name = member.name
        role = member.role
        backstory = member.backstory
        sigil = member.sigilRaw
        portraitData = member.portraitData
        sortIndex = member.sortIndex
        isRetired = member.isRetired
        createdAt = member.createdAt
    }

    func makeMember() -> PartyMember {
        let member = PartyMember(id: id, name: name, role: role, backstory: backstory, sortIndex: sortIndex, createdAt: createdAt)
        member.sigilRaw = sigil
        member.portraitData = portraitData
        member.isRetired = isRetired
        return member
    }
}

extension JournalBackup.JournalEntry {
    init(entry: Entry) {
        id = entry.id
        title = entry.title
        body = entry.body
        writtenAt = entry.writtenAt
        inGameDate = entry.inGameDate
        place = entry.place
        quest = entry.quest
        isTurningPoint = entry.isTurningPoint
        emotions = entry.emotions
        bonds = entry.bonds
        authorID = entry.author?.id
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
        photos = entry.sortedPhotos.compactMap { photo -> JournalBackup.Photo? in
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

    /// A new, unsaved entry. The author is looked up among `members` by ID.
    func makeEntry(members: [PartyMember]) -> Entry {
        let entry = Entry(
            id: id,
            title: title,
            body: body,
            writtenAt: writtenAt,
            inGameDate: inGameDate,
            place: place,
            quest: quest,
            isTurningPoint: isTurningPoint,
            emotions: emotions,
            bonds: bonds,
            createdAt: createdAt
        )
        entry.updatedAt = updatedAt
        entry.author = authorID.flatMap { id in members.first { $0.id == id } }
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
        var notebooksAdded = 0
        var entriesAdded = 0
        var sessionsAdded = 0
        /// Items whose IDs were already present (or repeated in the file).
        var skipped = 0

        var summary: String {
            var parts: [String] = []
            if notebooksAdded > 0 { parts.append("\(notebooksAdded) notebook\(notebooksAdded == 1 ? "" : "s")") }
            if entriesAdded > 0 { parts.append("\(entriesAdded) entr\(entriesAdded == 1 ? "y" : "ies")") }
            if sessionsAdded > 0 { parts.append("\(sessionsAdded) session\(sessionsAdded == 1 ? "" : "s")") }
            let added = parts.isEmpty ? "Nothing new to add." : "Added " + parts.joined(separator: ", ") + "."
            return skipped > 0 ? added + " Skipped \(skipped) already in your journal." : added
        }
    }

    /// Adds new notebooks whole; for notebooks already present, adds just the members and entries
    /// that are new. Sessions are added by ID and re-linked to their notebook.
    @MainActor
    static func importBackup(_ backup: JournalBackup, into context: ModelContext) throws -> Report {
        var report = Report()
        let existingNotebooks = try context.fetch(FetchDescriptor<Notebook>())
        var notebooksByID = Dictionary(existingNotebooks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var knownEntryIDs = Set(try context.fetch(FetchDescriptor<Entry>()).map(\.id))
        var knownMemberIDs = Set(try context.fetch(FetchDescriptor<PartyMember>()).map(\.id))

        for record in backup.notebooks ?? [] {
            if let notebook = notebooksByID[record.id] {
                var members = notebook.members ?? []
                for memberRecord in record.members where knownMemberIDs.insert(memberRecord.id).inserted {
                    let member = memberRecord.makeMember()
                    context.insert(member)
                    member.notebook = notebook
                    members.append(member)
                }
                for entryRecord in record.entries {
                    guard knownEntryIDs.insert(entryRecord.id).inserted else {
                        report.skipped += 1
                        continue
                    }
                    let entry = entryRecord.makeEntry(members: members)
                    context.insert(entry)
                    entry.notebook = notebook
                    report.entriesAdded += 1
                }
                report.skipped += 1
            } else {
                let notebook = record.makeNotebook()
                context.insert(notebook)
                notebooksByID[record.id] = notebook
                record.members.forEach { knownMemberIDs.insert($0.id) }
                record.entries.forEach { knownEntryIDs.insert($0.id) }
                report.notebooksAdded += 1
                report.entriesAdded += record.entries.count
            }
        }

        let plan = backup.mergePlan(existingIDs: Set(try context.fetch(FetchDescriptor<PlaySession>()).map(\.id)))
        for record in plan.newSessions {
            let session = record.makeSession()
            context.insert(session)
            session.notebook = record.notebookID.flatMap { notebooksByID[$0] }
        }
        report.sessionsAdded = plan.newSessions.count
        report.skipped += plan.skippedCount
        try context.save()
        return report
    }
}
