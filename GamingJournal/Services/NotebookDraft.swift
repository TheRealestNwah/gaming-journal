import Foundation
import SwiftData

/// Editable copy of a notebook's fields, so the editor can be cancelled without touching the model.
struct NotebookDraft: Equatable {
    var title = ""
    var gameTitle = ""
    var platform = ""
    var coverStyle: CoverStyle = .ember
    var status: NotebookStatus = .ongoing
    var startedAt = Date.now
    var summary = ""

    init() {}

    init(notebook: Notebook) {
        title = notebook.title
        gameTitle = notebook.gameTitle
        platform = notebook.platform
        coverStyle = notebook.coverStyle
        status = notebook.status
        startedAt = notebook.startedAt
        summary = notebook.summary
    }

    private static func tidy(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The title to save: what was typed, or the game's name when the title is left blank.
    var resolvedTitle: String {
        let title = Self.tidy(self.title)
        return title.isEmpty ? Self.tidy(gameTitle) : title
    }

    /// A notebook needs a title or at least a game to name it after.
    var isValid: Bool {
        !resolvedTitle.isEmpty
    }

    func makeNotebook(now: Date = .now) -> Notebook {
        let notebook = Notebook(title: resolvedTitle, createdAt: now)
        apply(to: notebook, now: now)
        return notebook
    }

    func apply(to notebook: Notebook, now: Date = .now) {
        notebook.title = resolvedTitle
        notebook.gameTitle = Self.tidy(gameTitle)
        notebook.platform = Self.tidy(platform)
        notebook.coverStyle = coverStyle
        notebook.status = status
        notebook.startedAt = startedAt
        notebook.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        notebook.touch(now)
    }
}

/// A detached copy of a notebook and everything in it, taken before deleting so undo can put it
/// back with the same IDs. Play sessions aren't deleted with a notebook, so they're re-linked.
struct NotebookSnapshot {
    private let notebook: Notebook
    private let sessions: [PlaySession]

    init(_ source: Notebook) {
        let copy = Notebook(
            id: source.id,
            title: source.title,
            gameTitle: source.gameTitle,
            platform: source.platform,
            coverStyle: source.coverStyle,
            status: source.status,
            startedAt: source.startedAt,
            summary: source.summary,
            createdAt: source.createdAt
        )
        copy.updatedAt = source.updatedAt

        var membersByID: [UUID: PartyMember] = [:]
        copy.members = (source.members ?? []).map { member in
            let clone = PartyMember(
                id: member.id,
                name: member.name,
                role: member.role,
                backstory: member.backstory,
                sigil: member.sigil,
                sortIndex: member.sortIndex,
                createdAt: member.createdAt
            )
            clone.portraitData = member.portraitData
            clone.isRetired = member.isRetired
            membersByID[member.id] = clone
            return clone
        }

        copy.entries = (source.entries ?? []).map { entry in
            let clone = Entry(
                id: entry.id,
                title: entry.title,
                body: entry.body,
                writtenAt: entry.writtenAt,
                inGameDate: entry.inGameDate,
                place: entry.place,
                quest: entry.quest,
                isTurningPoint: entry.isTurningPoint,
                createdAt: entry.createdAt
            )
            clone.emotionsData = entry.emotionsData
            clone.bondsData = entry.bondsData
            clone.updatedAt = entry.updatedAt
            clone.author = entry.author.flatMap { membersByID[$0.id] }
            clone.photos = entry.sortedPhotos.map { photo in
                EntryPhoto(
                    id: photo.id,
                    imageData: photo.imageData,
                    thumbnailData: photo.thumbnailData,
                    sortIndex: photo.sortIndex,
                    createdAt: photo.createdAt
                )
            }
            return clone
        }

        notebook = copy
        sessions = source.sessions ?? []
    }

    var title: String { notebook.title }

    /// Inserts the copy and re-links its sessions (those that still exist).
    func restore(into context: ModelContext) {
        context.insert(notebook)
        for session in sessions where session.modelContext != nil && !session.isDeleted {
            session.notebook = notebook
        }
    }
}

extension ModelContext {
    /// Deletes a notebook with its party and entries, and offers to put it all back.
    @MainActor
    func deleteNotebook(_ notebook: Notebook, undo center: UndoCenter) {
        let snapshot = NotebookSnapshot(notebook)
        delete(notebook)
        try? save()
        center.offer("Deleted \(snapshot.title)") {
            snapshot.restore(into: self)
            try? self.save()
        }
    }
}
