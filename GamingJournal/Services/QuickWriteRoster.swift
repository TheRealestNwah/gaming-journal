import Foundation
import WidgetKit

/// The journals Siri, Shortcuts and the "Write in…" widget can offer, kept in the App Group so
/// they can list them without opening the journal's store.
struct QuickWriteRoster: Codable, Equatable {
    static let key = "quickWriteRoster"

    /// A journal as Siri lists it.
    struct Book: Codable, Equatable, Identifiable {
        var id: UUID
        var characterName: String
        var epithet: String
        var gameTitle: String
    }

    /// Most recently written in first.
    var journals: [Book]

    init(books: [Book] = []) {
        journals = books
    }

    init(journals: [Journal]) {
        self.journals = journals
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { Book(id: $0.id, characterName: $0.characterName, epithet: $0.epithet, gameTitle: $0.gameTitle) }
    }

    /// Journals whose character, epithet or game contains the text (all of them for a blank query).
    func journals(matching text: String) -> [Book] {
        let needle = SearchText.normalize(text)
        guard !needle.isEmpty else { return journals }
        return journals.filter { SearchText.normalize("\($0.characterName) \($0.epithet) \($0.gameTitle)").contains(needle) }
    }

    // MARK: Storage

    static func load(from defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) -> QuickWriteRoster {
        guard let data = defaults?.data(forKey: key),
              let roster = try? JSONDecoder().decode(QuickWriteRoster.self, from: data)
        else { return QuickWriteRoster() }
        return roster
    }

    /// Saves when changed; returns whether it did, so callers know to refresh Siri's phrases.
    @discardableResult
    func save(to defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) -> Bool {
        guard let defaults, Self.load(from: defaults) != self, let data = try? JSONEncoder().encode(self) else { return false }
        defaults.set(data, forKey: Self.key)
        // The "Write in…" widget lists journals.
        WidgetCenter.shared.reloadTimelines(ofKind: "WriteAs")
        return true
    }
}
