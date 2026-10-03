import Foundation
import SwiftData

/// User-initiated mutations either save completely or restore the last saved state.
/// Flush pre-existing edits first so rolling back a failed operation does not discard them.
@MainActor
enum JournalStore {
    static func commit<T>(in context: ModelContext,
                          save: (ModelContext) throws -> Void = { try $0.save() },
                          changes: () throws -> T) throws -> T {
        if context.hasChanges { try context.save() }
        let autosave = context.autosaveEnabled
        let previousUndo = context.undoManager
        // A local group restores the observable model graph as well as the store's pending work.
        // ModelContext.rollback alone can leave registered SwiftData relationship caches stale.
        let undo = UndoManager()
        undo.groupsByEvent = false
        context.undoManager = undo
        context.autosaveEnabled = false
        defer {
            context.undoManager = previousUndo
            context.autosaveEnabled = autosave
        }
        undo.beginUndoGrouping()
        do {
            let value = try changes()
            // Register relationship and property changes before a save can fail synchronously.
            context.processPendingChanges()
            undo.endUndoGrouping()
            try save(context)
            return value
        } catch {
            context.processPendingChanges()
            if undo.groupingLevel > 0 { undo.endUndoGrouping() }
            if undo.canUndo { undo.undo() }
            context.processPendingChanges()
            context.rollback()
            context.processPendingChanges()
            throw error
        }
    }

    static func save(_ draft: EntryDraft, entry: Entry?, in journal: Journal,
                     context: ModelContext, drafts: DraftShelf = DraftShelf(),
                     persist: (ModelContext) throws -> Void = { try $0.save() }) throws {
        try commit(in: context, save: persist) {
            let destination: Entry
            var page = draft
            if let entry {
                destination = entry
            } else {
                destination = Entry()
                context.insert(destination)
                page.writtenAt = .now
            }
            page.apply(to: destination, in: journal)
        }
        if entry == nil { drafts.discard(for: journal.id) }
    }
}

/// User cancellation is not a failed export/import.
enum FileOperation {
    static func isCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
    }
}
