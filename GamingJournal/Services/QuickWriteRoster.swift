import Foundation

/// The notebooks and characters Siri and Shortcuts can offer for "Write as…", kept in the App
/// Group so intents can list them without opening the journal's store.
struct QuickWriteRoster: Codable, Equatable {
    static let key = "quickWriteRoster"

    struct Tale: Codable, Equatable, Identifiable {
        var id: UUID
        var title: String
        var gameTitle: String
    }

    struct Character: Codable, Equatable, Identifiable {
        var id: UUID
        var name: String
        var role: String
        var notebookID: UUID
        var notebookTitle: String
    }

    /// Ongoing tales first, then most recently touched.
    var tales: [Tale]
    /// Active party members of those tales, in tale then party order.
    var characters: [Character]

    init(tales: [Tale] = [], characters: [Character] = []) {
        self.tales = tales
        self.characters = characters
    }

    init(notebooks: [Notebook]) {
        let ordered = notebooks.sorted {
            if ($0.status == .ongoing) != ($1.status == .ongoing) { return $0.status == .ongoing }
            return $0.updatedAt > $1.updatedAt
        }
        tales = ordered.map { Tale(id: $0.id, title: $0.title, gameTitle: $0.gameTitle) }
        characters = ordered.flatMap { notebook in
            notebook.party.filter { !$0.isRetired }.map {
                Character(id: $0.id, name: $0.name, role: $0.role, notebookID: notebook.id, notebookTitle: notebook.title)
            }
        }
    }

    /// Characters whose name, role or tale contains the text (all of them for a blank query).
    func characters(matching text: String) -> [Character] {
        let needle = ChronicleFilter.normalize(text)
        guard !needle.isEmpty else { return characters }
        return characters.filter { ChronicleFilter.normalize("\($0.name) \($0.role) \($0.notebookTitle)").contains(needle) }
    }

    func tales(matching text: String) -> [Tale] {
        let needle = ChronicleFilter.normalize(text)
        guard !needle.isEmpty else { return tales }
        return tales.filter { ChronicleFilter.normalize("\($0.title) \($0.gameTitle)").contains(needle) }
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
        return true
    }
}
