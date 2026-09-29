import Foundation
import SwiftData

/// The schema the app reads and writes. Older versions are only kept for migration.
typealias CurrentSchema = JournalSchemaV2

typealias Notebook = CurrentSchema.Notebook
typealias PartyMember = CurrentSchema.PartyMember
typealias Chapter = CurrentSchema.Chapter
typealias Entry = CurrentSchema.Entry
typealias EntryPhoto = CurrentSchema.EntryPhoto
typealias PlaySession = CurrentSchema.PlaySession
typealias SessionPhoto = CurrentSchema.SessionPhoto

enum GamingJournalMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [JournalSchemaV1.self, JournalSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2]
    }

    /// Chapters and pinning are purely additive, so SwiftData can infer the mapping.
    static var v1ToV2: MigrationStage {
        .lightweight(fromVersion: JournalSchemaV1.self, toVersion: JournalSchemaV2.self)
    }
}

// MARK: - Notebook

extension Notebook {
    var coverStyle: CoverStyle {
        get { CoverStyle(rawValue: coverStyleRaw) ?? .ember }
        set { coverStyleRaw = newValue.rawValue }
    }

    var status: NotebookStatus {
        get { NotebookStatus(rawValue: statusRaw) ?? .ongoing }
        set { statusRaw = newValue.rawValue }
    }

    /// Party in order, retired members last.
    var party: [PartyMember] {
        (members ?? []).sorted {
            if $0.isRetired != $1.isRetired { return !$0.isRetired }
            return ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt)
        }
    }

    /// Entries newest first.
    var chronicle: [Entry] {
        (entries ?? []).sorted { ($0.writtenAt, $0.createdAt) > ($1.writtenAt, $1.createdAt) }
    }

    /// Chapters in story order.
    var orderedChapters: [Chapter] {
        (chapters ?? []).sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
    }
}

// MARK: - Chapter

extension Chapter {
    /// Its entries, oldest first, the way they read in the book.
    var story: [Entry] {
        (entries ?? []).sorted { ($0.writtenAt, $0.createdAt) < ($1.writtenAt, $1.createdAt) }
    }
}

// MARK: - Party member

extension PartyMember {
    var sigil: Sigil {
        get { Sigil(rawValue: sigilRaw) ?? .ember }
        set { sigilRaw = newValue.rawValue }
    }

    /// Their entries, newest first.
    var journal: [Entry] {
        (entries ?? []).sorted { ($0.writtenAt, $0.createdAt) > ($1.writtenAt, $1.createdAt) }
    }
}

// MARK: - Entry

extension Entry {
    var emotions: [FeltEmotion] {
        get { EntryCoding.decode([FeltEmotion].self, from: emotionsData) ?? [] }
        set { emotionsData = EntryCoding.encode(FeltEmotion.normalized(newValue)) }
    }

    var bonds: [Bond] {
        get { EntryCoding.decode([Bond].self, from: bondsData) ?? [] }
        set { bondsData = EntryCoding.encode(newValue.map { $0.clamped() }) }
    }

    var sortedPhotos: [EntryPhoto] {
        (photos ?? []).sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }
    }

    /// Word count of the body, for Journey stats.
    var wordCount: Int {
        body.split { $0.isWhitespace || $0.isNewline }.count
    }
}

// MARK: - Play session

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
