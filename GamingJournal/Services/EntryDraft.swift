import Foundation
import SwiftData

/// Editable copy of an entry, so the editor can be cancelled without touching the model.
struct EntryDraft: Equatable {
    var title = ""
    var body = ""
    var writtenAt = Date.now
    var inGameDate = ""
    var place = ""
    var quest = ""
    var isTurningPoint = false
    /// The party member writing; nil for an unsigned (narrator) entry.
    var authorID: UUID?
    /// The chapter it belongs to; nil for none.
    var chapterID: UUID?
    var emotions: [FeltEmotion] = []
    var bonds: [Bond] = []
    var photos: [DraftPhoto] = []

    init(authorID: UUID? = nil, chapterID: UUID? = nil) {
        self.authorID = authorID
        self.chapterID = chapterID
    }

    /// A fresh entry in the notebook's current chapter, by `author` or else the party's first
    /// active member.
    static func new(in notebook: Notebook, author: PartyMember? = nil) -> EntryDraft {
        EntryDraft(
            authorID: author?.id ?? notebook.party.first { !$0.isRetired }?.id,
            chapterID: ChapterBook.current(in: notebook)?.id
        )
    }

    /// A fresh entry dated to a play session, written by the party's first active member.
    static func afterSession(in notebook: Notebook, startedAt: Date) -> EntryDraft {
        var draft = EntryDraft.new(in: notebook)
        draft.writtenAt = startedAt
        return draft
    }

    init(entry: Entry) {
        title = entry.title
        body = entry.body
        writtenAt = entry.writtenAt
        inGameDate = entry.inGameDate
        place = entry.place
        quest = entry.quest
        isTurningPoint = entry.isTurningPoint
        authorID = entry.author?.id
        chapterID = entry.chapter?.id
        emotions = entry.emotions
        bonds = entry.bonds
        photos = entry.sortedPhotos.compactMap { photo -> DraftPhoto? in
            guard let image = photo.imageData else { return nil }
            return DraftPhoto(id: photo.id, imageData: image, thumbnailData: photo.thumbnailData ?? image)
        }
    }

    private static func tidy(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Something worth keeping: a title, some writing, or at least a feeling.
    var isValid: Bool {
        !Self.tidy(title).isEmpty
            || !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !emotions.isEmpty
    }

    // MARK: Emotions

    func intensity(of emotion: Emotion) -> Int? {
        emotions.first { $0.emotion == emotion }?.intensity
    }

    /// Tap behaviour for an emotion chip: add at 1, then 2, then 3, then remove.
    mutating func cycle(_ emotion: Emotion) {
        if let index = emotions.firstIndex(where: { $0.emotion == emotion }) {
            if emotions[index].intensity >= FeltEmotion.intensityRange.upperBound {
                emotions.remove(at: index)
            } else {
                emotions[index].intensity += 1
            }
        } else {
            emotions.append(FeltEmotion(emotion, intensity: 1))
        }
    }

    // MARK: Saving

    func makeEntry(in notebook: Notebook, now: Date = .now) -> Entry {
        let entry = Entry(createdAt: now)
        apply(to: entry, in: notebook, now: now)
        return entry
    }

    /// Writes the draft into `entry`. The entry must already be in a context (or will be inserted
    /// alongside the notebook) for photo removal to take effect.
    func apply(to entry: Entry, in notebook: Notebook, now: Date = .now) {
        entry.title = Self.tidy(title)
        entry.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.writtenAt = writtenAt
        entry.inGameDate = Self.tidy(inGameDate)
        entry.place = Self.tidy(place)
        entry.quest = Self.tidy(quest)
        entry.isTurningPoint = isTurningPoint
        entry.emotions = emotions
        entry.bonds = bonds.filter { !$0.targetName.isEmpty }
        entry.author = authorID.flatMap { id in (notebook.members ?? []).first { $0.id == id } }
        entry.chapter = chapterID.flatMap { id in (notebook.chapters ?? []).first { $0.id == id } }
        entry.updatedAt = now
        applyPhotos(to: entry)
        notebook.touch(now)
    }

    private func applyPhotos(to entry: Entry) {
        let existing = entry.photos ?? []
        let keptIDs = Set(photos.map(\.id))
        for photo in existing where !keptIDs.contains(photo.id) {
            photo.modelContext?.delete(photo)
        }
        var remaining = existing.filter { keptIDs.contains($0.id) }
        for (index, draftPhoto) in photos.enumerated() {
            if let photo = remaining.first(where: { $0.id == draftPhoto.id }) {
                photo.sortIndex = index
            } else {
                remaining.append(EntryPhoto(
                    id: draftPhoto.id,
                    imageData: draftPhoto.imageData,
                    thumbnailData: draftPhoto.thumbnailData,
                    sortIndex: index
                ))
            }
        }
        entry.photos = remaining
    }
}

/// A detached copy of an entry, taken before deleting so undo can put it back.
struct EntrySnapshot {
    private let entry: Entry
    private let notebook: Notebook?
    private let author: PartyMember?
    private let chapter: Chapter?

    init(_ source: Entry) {
        let copy = Entry(
            id: source.id,
            title: source.title,
            body: source.body,
            writtenAt: source.writtenAt,
            inGameDate: source.inGameDate,
            place: source.place,
            quest: source.quest,
            isTurningPoint: source.isTurningPoint,
            createdAt: source.createdAt
        )
        copy.emotionsData = source.emotionsData
        copy.bondsData = source.bondsData
        copy.updatedAt = source.updatedAt
        copy.photos = source.sortedPhotos.map { photo in
            EntryPhoto(
                id: photo.id,
                imageData: photo.imageData,
                thumbnailData: photo.thumbnailData,
                sortIndex: photo.sortIndex,
                createdAt: photo.createdAt
            )
        }
        entry = copy
        notebook = source.notebook
        author = source.author
        chapter = source.chapter
    }

    var title: String { entry.title }

    func restore(into context: ModelContext) {
        context.insert(entry)
        if let notebook, notebook.modelContext != nil, !notebook.isDeleted {
            entry.notebook = notebook
        }
        if let author, author.modelContext != nil, !author.isDeleted {
            entry.author = author
        }
        if let chapter, chapter.modelContext != nil, !chapter.isDeleted {
            entry.chapter = chapter
        }
    }
}

extension ModelContext {
    /// Deletes an entry and offers to put it back.
    @MainActor
    func deleteEntry(_ entry: Entry, undo center: UndoCenter) {
        let snapshot = EntrySnapshot(entry)
        entry.notebook?.touch()
        delete(entry)
        try? save()
        center.offer(snapshot.title.isEmpty ? "Deleted entry" : "Deleted “\(snapshot.title)”") {
            snapshot.restore(into: self)
            try? self.save()
        }
    }
}
