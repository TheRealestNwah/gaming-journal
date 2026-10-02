import AppIntents
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// A character's journal Siri and Shortcuts can write in.
struct JournalEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Journal")
    static let defaultQuery = JournalQuery()

    let id: UUID
    let characterName: String
    let subtitle: String

    init(_ journal: QuickWriteRoster.Book) {
        id = journal.id
        characterName = journal.characterName
        subtitle = [journal.epithet, journal.gameTitle].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(characterName)",
            subtitle: subtitle.isEmpty ? nil : LocalizedStringResource(stringLiteral: subtitle)
        )
    }
}

struct JournalQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [JournalEntity] {
        QuickWriteRoster.load().journals.filter { identifiers.contains($0.id) }.map(JournalEntity.init)
    }

    func entities(matching string: String) async throws -> [JournalEntity] {
        QuickWriteRoster.load().journals(matching: string).map(JournalEntity.init)
    }

    func suggestedEntities() async throws -> [JournalEntity] {
        QuickWriteRoster.load().journals.map(JournalEntity.init)
    }
}

/// Opens a new page in a character's journal.
struct WriteAsCharacterIntent: AppIntent {
    static let title: LocalizedStringResource = "Write as Character"
    static let description = IntentDescription("Open a new page in a character's journal.")
    static let openAppWhenRun = true

    @Parameter(title: "Character")
    var journal: JournalEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Write as \(\.$journal)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if os(macOS)
        NSWorkspace.shared.open(WidgetSnapshot.writeURL(for: journal.id))
        #else
        _ = await UIApplication.shared.open(WidgetSnapshot.writeURL(for: journal.id))
        #endif
        return .result()
    }
}

/// Opens a new page in the journal written in most recently.
struct WriteInJournalIntent: AppIntent {
    static let title: LocalizedStringResource = "Write in Journal"
    static let description = IntentDescription("Open a new page in your most recent journal.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        #if os(macOS)
        NSWorkspace.shared.open(WidgetSnapshot.writeURL)
        #else
        _ = await UIApplication.shared.open(WidgetSnapshot.writeURL)
        #endif
        return .result()
    }
}

/// Phrases that work without setting anything up in Shortcuts.
struct QuickWriteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WriteAsCharacterIntent(),
            phrases: [
                "Write as \(\.$journal) in \(.applicationName)",
                "Open \(\.$journal)'s journal in \(.applicationName)",
            ],
            shortTitle: "Write as…",
            systemImageName: "person.crop.circle.badge.plus"
        )
        AppShortcut(
            intent: WriteInJournalIntent(),
            phrases: [
                "Write in \(.applicationName)",
                "New \(.applicationName) entry",
            ],
            shortTitle: "Write in Journal",
            systemImageName: "pencil.and.scribble"
        )
    }
}
