import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// Puts journals and entries into iOS search. The whole index is rebuilt from the store, which
/// stays quick for a hand-written journal and can never drift out of step with deletions.
enum SpotlightIndex {
    static let enabledKey = "spotlight.enabled"
    static let journalDomain = "journals"
    static let entryDomain = "entries"

    /// What a search result points at.
    enum Target: Equatable {
        case journal(UUID)
        case entry(UUID)

        var identifier: String {
            switch self {
            case .journal(let id): "journal.\(id.uuidString)"
            case .entry(let id): "entry.\(id.uuidString)"
            }
        }

        init?(identifier: String) {
            let parts = identifier.split(separator: ".", maxSplits: 1).map(String.init)
            guard parts.count == 2, let id = UUID(uuidString: parts[1]) else { return nil }
            switch parts[0] {
            case "journal": self = .journal(id)
            case "entry": self = .entry(id)
            default: return nil
            }
        }
    }

    /// On unless turned off in Settings.
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? true
    }

    static func item(for journal: Journal) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = journal.title
        attributes.contentDescription = journal.subtitle
        attributes.keywords = [journal.characterName, journal.epithet, journal.gameTitle].filter { !$0.isEmpty }
        return CSSearchableItem(
            uniqueIdentifier: Target.journal(journal.id).identifier,
            domainIdentifier: journalDomain,
            attributeSet: attributes
        )
    }

    /// With `includeText` off (the journal is locked) only the date and whose journal it is are
    /// searchable, never what was written.
    static func item(for entry: Entry, includeText: Bool) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = entry.headingWithPlace()
        let byline = entry.journal?.title ?? ""
        if includeText {
            let body = entry.body.split(whereSeparator: \.isNewline).joined(separator: " ")
            attributes.contentDescription = body.isEmpty ? byline : "\(byline) — \(body.prefix(300))"
        } else {
            attributes.contentDescription = byline
        }
        attributes.keywords = [entry.journal?.characterName ?? "", entry.inGameDate, entry.place].filter { !$0.isEmpty }
        attributes.contentCreationDate = entry.writtenAt
        return CSSearchableItem(
            uniqueIdentifier: Target.entry(entry.id).identifier,
            domainIdentifier: entryDomain,
            attributeSet: attributes
        )
    }

    static func items(journals: [Journal], includeText: Bool) -> [CSSearchableItem] {
        journals.flatMap { journal in
            [item(for: journal)] + (journal.entries ?? []).map { item(for: $0, includeText: includeText) }
        }
    }

    /// Replaces the index with the journals as they are now, or clears it when indexing is off.
    static func rebuild(journals: [Journal], defaults: UserDefaults = .standard) {
        let index = CSSearchableIndex.default()
        let items = isEnabled(in: defaults)
            ? items(journals: journals, includeText: !AppLock.isEnabled(in: defaults))
            : []
        index.deleteAllSearchableItems { _ in
            guard !items.isEmpty else { return }
            index.indexSearchableItems(items)
        }
    }
}
