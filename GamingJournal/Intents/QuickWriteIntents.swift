import AppIntents
import UIKit

/// A party member Siri and Shortcuts can write as.
struct CharacterEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Character")
    static let defaultQuery = CharacterQuery()

    let id: UUID
    let name: String
    let role: String
    let notebookID: UUID
    let notebookTitle: String

    init(_ character: QuickWriteRoster.Character) {
        id = character.id
        name = character.name
        role = character.role
        notebookID = character.notebookID
        notebookTitle = character.notebookTitle
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\([role, notebookTitle].filter { !$0.isEmpty }.joined(separator: " · "))"
        )
    }
}

struct CharacterQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [CharacterEntity] {
        QuickWriteRoster.load().characters.filter { identifiers.contains($0.id) }.map(CharacterEntity.init)
    }

    func entities(matching string: String) async throws -> [CharacterEntity] {
        QuickWriteRoster.load().characters(matching: string).map(CharacterEntity.init)
    }

    func suggestedEntities() async throws -> [CharacterEntity] {
        QuickWriteRoster.load().characters.map(CharacterEntity.init)
    }
}

/// A notebook Siri and Shortcuts can open for writing.
struct TaleEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Notebook")
    static let defaultQuery = TaleQuery()

    let id: UUID
    let title: String
    let gameTitle: String

    init(_ tale: QuickWriteRoster.Tale) {
        id = tale.id
        title = tale.title
        gameTitle = tale.gameTitle
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: gameTitle.isEmpty ? nil : LocalizedStringResource(stringLiteral: gameTitle)
        )
    }
}

struct TaleQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [TaleEntity] {
        QuickWriteRoster.load().tales.filter { identifiers.contains($0.id) }.map(TaleEntity.init)
    }

    func entities(matching string: String) async throws -> [TaleEntity] {
        QuickWriteRoster.load().tales(matching: string).map(TaleEntity.init)
    }

    func suggestedEntities() async throws -> [TaleEntity] {
        QuickWriteRoster.load().tales.map(TaleEntity.init)
    }
}

/// Opens the entry editor in the character's notebook, signed by them.
struct WriteAsCharacterIntent: AppIntent {
    static let title: LocalizedStringResource = "Write as Character"
    static let description = IntentDescription("Start a journal entry in a character's voice.")
    static let openAppWhenRun = true

    @Parameter(title: "Character")
    var character: CharacterEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Write as \(\.$character)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await UIApplication.shared.open(WidgetSnapshot.writeURL(for: character.notebookID, member: character.id))
        return .result()
    }
}

/// Opens the entry editor in a notebook, or the current tale when none is chosen.
struct WriteInNotebookIntent: AppIntent {
    static let title: LocalizedStringResource = "Write in Journal"
    static let description = IntentDescription("Start a journal entry in a notebook.")
    static let openAppWhenRun = true

    @Parameter(title: "Notebook")
    var notebook: TaleEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Write in \(\.$notebook)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let url = notebook.map { WidgetSnapshot.writeURL(for: $0.id) } ?? WidgetSnapshot.writeURL
        _ = await UIApplication.shared.open(url)
        return .result()
    }
}

/// Phrases that work without setting anything up in Shortcuts.
struct QuickWriteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WriteAsCharacterIntent(),
            phrases: [
                "Write as \(\.$character) in \(.applicationName)",
                "Start a \(.applicationName) entry as \(\.$character)",
            ],
            shortTitle: "Write as…",
            systemImageName: "person.crop.circle.badge.plus"
        )
        AppShortcut(
            intent: WriteInNotebookIntent(),
            phrases: [
                "Write in \(.applicationName)",
                "New \(.applicationName) entry",
            ],
            shortTitle: "Write in Journal",
            systemImageName: "pencil.and.scribble"
        )
    }
}
