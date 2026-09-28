import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// Puts notebooks and entries into iOS search. The whole index is rebuilt from the store, which
/// stays quick for a hand-written journal and can never drift out of step with deletions.
enum SpotlightIndex {
    static let enabledKey = "spotlight.enabled"
    static let notebookDomain = "notebooks"
    static let entryDomain = "entries"

    /// What a search result points at.
    enum Target: Equatable {
        case notebook(UUID)
        case entry(UUID)

        var identifier: String {
            switch self {
            case .notebook(let id): "notebook.\(id.uuidString)"
            case .entry(let id): "entry.\(id.uuidString)"
            }
        }

        init?(identifier: String) {
            let parts = identifier.split(separator: ".", maxSplits: 1).map(String.init)
            guard parts.count == 2, let id = UUID(uuidString: parts[1]) else { return nil }
            switch parts[0] {
            case "notebook": self = .notebook(id)
            case "entry": self = .entry(id)
            default: return nil
            }
        }
    }

    /// On unless turned off in Settings.
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? true
    }

    static func item(for notebook: Notebook) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = notebook.title
        attributes.contentDescription = [notebook.gameTitle, notebook.platform, notebook.status.label]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        attributes.keywords = [notebook.gameTitle] + notebook.party.map(\.name)
        return CSSearchableItem(
            uniqueIdentifier: Target.notebook(notebook.id).identifier,
            domainIdentifier: notebookDomain,
            attributeSet: attributes
        )
    }

    /// With `includeText` off (the journal is locked) only the title, writer and notebook are
    /// searchable, never what was written.
    static func item(for entry: Entry, includeText: Bool) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        let writer = entry.author?.name ?? "Narrator"
        attributes.title = entry.title.isEmpty ? "\(writer)'s entry" : entry.title
        let byline = [entry.notebook?.title ?? "", writer].filter { !$0.isEmpty }.joined(separator: " · ")
        if includeText {
            let body = entry.body.split(whereSeparator: \.isNewline).joined(separator: " ")
            attributes.contentDescription = body.isEmpty ? byline : "\(byline) — \(body.prefix(300))"
            attributes.keywords = [entry.place, entry.quest, writer].filter { !$0.isEmpty }
        } else {
            attributes.contentDescription = byline
            attributes.keywords = [writer]
        }
        attributes.contentCreationDate = entry.writtenAt
        return CSSearchableItem(
            uniqueIdentifier: Target.entry(entry.id).identifier,
            domainIdentifier: entryDomain,
            attributeSet: attributes
        )
    }

    static func items(notebooks: [Notebook], includeText: Bool) -> [CSSearchableItem] {
        notebooks.flatMap { notebook in
            [item(for: notebook)] + (notebook.entries ?? []).map { item(for: $0, includeText: includeText) }
        }
    }

    /// Replaces the index with the journal as it is now, or clears it when indexing is off.
    static func rebuild(notebooks: [Notebook], defaults: UserDefaults = .standard) {
        let index = CSSearchableIndex.default()
        let items = isEnabled(in: defaults)
            ? items(notebooks: notebooks, includeText: !AppLock.isEnabled(in: defaults))
            : []
        index.deleteAllSearchableItems { _ in
            guard !items.isEmpty else { return }
            index.indexSearchableItems(items)
        }
    }
}
