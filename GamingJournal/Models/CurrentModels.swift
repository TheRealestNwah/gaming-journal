import Foundation
import SwiftData

/// The schema the app reads and writes.
typealias CurrentSchema = HearthboundSchemaV1

typealias Journal = CurrentSchema.Journal
typealias Entry = CurrentSchema.Entry
typealias EntryPhoto = CurrentSchema.EntryPhoto

enum HearthboundMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [HearthboundSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

// MARK: - Journal

extension Journal {
    var coverStyle: CoverStyle {
        get { CoverStyle(rawValue: coverStyleRaw) ?? .ember }
        set { coverStyleRaw = newValue.rawValue }
    }

    /// "The Journal of Eira Stormborn".
    var title: String {
        "The Journal of \(characterName)"
    }

    /// "Nord Dragonborn · Skyrim", or whichever of the two is filled in.
    var subtitle: String {
        [epithet, gameTitle].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Entries oldest first, the way they read in the book.
    var story: [Entry] {
        (entries ?? []).sorted { ($0.writtenAt, $0.createdAt) < ($1.writtenAt, $1.createdAt) }
    }

    var latestEntry: Entry? {
        (entries ?? []).max { ($0.writtenAt, $0.createdAt) < ($1.writtenAt, $1.createdAt) }
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
    }
}

// MARK: - Entry

extension Entry {
    var sortedPhotos: [EntryPhoto] {
        (photos ?? []).sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }
    }

    /// What heads the entry on the page: its in-game date, or else the day it was written.
    func heading(locale: Locale = .current) -> String {
        guard inGameDate.isEmpty else { return inGameDate }
        var style = Date.FormatStyle(date: .long, time: .omitted)
        style.locale = locale
        return writtenAt.formatted(style)
    }
}

/// Case- and accent-insensitive text for matching names typed into Siri or Shortcuts.
enum SearchText {
    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
