import AppIntents
import SwiftUI
import WidgetKit

/// Mirror of the app's `QuickWriteRoster`: the characters the app keeps in the App Group.
struct Roster: Codable {
    static let key = "quickWriteRoster"

    struct Character: Codable {
        var id: UUID
        var name: String
        var role: String
        var notebookID: UUID
        var notebookTitle: String
    }

    var characters: [Character]

    static func load() -> Roster {
        guard let data = UserDefaults(suiteName: Snapshot.appGroup)?.data(forKey: key),
              let roster = try? JSONDecoder().decode(Roster.self, from: data)
        else { return Roster(characters: []) }
        return roster
    }
}

extension Snapshot {
    /// Mirror of the app's `WidgetSnapshot.writeURL(for:member:)`.
    static func writeURL(for notebookID: UUID, member memberID: UUID) -> URL {
        var components = URLComponents(url: writeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "notebook", value: notebookID.uuidString),
            URLQueryItem(name: "member", value: memberID.uuidString),
        ]
        return components.url!
    }
}

// MARK: Configuration

struct WidgetCharacter: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Character")
    static let defaultQuery = WidgetCharacterQuery()

    let id: UUID
    let name: String
    let role: String
    let notebookID: UUID
    let notebookTitle: String

    init(_ character: Roster.Character) {
        id = character.id
        name = character.name
        role = character.role
        notebookID = character.notebookID
        notebookTitle = character.notebookTitle
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(notebookTitle)")
    }
}

struct WidgetCharacterQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [WidgetCharacter] {
        Roster.load().characters.filter { identifiers.contains($0.id) }.map(WidgetCharacter.init)
    }

    func suggestedEntities() async throws -> [WidgetCharacter] {
        Roster.load().characters.map(WidgetCharacter.init)
    }

    func defaultResult() async -> WidgetCharacter? {
        Roster.load().characters.first.map(WidgetCharacter.init)
    }
}

struct WriteAsConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Write as"
    static let description = IntentDescription("Start an entry in a character's voice.")

    @Parameter(title: "Character")
    var character: WidgetCharacter?
}

// MARK: Widget

struct WriteAsEntry: TimelineEntry {
    let date: Date
    let character: WidgetCharacter?
}

struct WriteAsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WriteAsEntry {
        WriteAsEntry(date: .now, character: nil)
    }

    func snapshot(for configuration: WriteAsConfiguration, in context: Context) async -> WriteAsEntry {
        WriteAsEntry(date: .now, character: await resolve(configuration))
    }

    func timeline(for configuration: WriteAsConfiguration, in context: Context) async -> Timeline<WriteAsEntry> {
        // The app reloads this widget whenever the party changes.
        Timeline(entries: [WriteAsEntry(date: .now, character: await resolve(configuration))], policy: .never)
    }

    /// The chosen character if they're still in an active party, else the first one.
    private func resolve(_ configuration: WriteAsConfiguration) async -> WidgetCharacter? {
        let characters = Roster.load().characters
        if let chosen = configuration.character, let current = characters.first(where: { $0.id == chosen.id }) {
            return WidgetCharacter(current)
        }
        return characters.first.map(WidgetCharacter.init)
    }
}

/// A character's quill on the Home or Lock Screen: tap to write as them.
struct WriteAsWidget: Widget {
    static let kind = "WriteAs"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: WriteAsConfiguration.self, provider: WriteAsProvider()) { entry in
            WriteAsView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(red: 0.96, green: 0.91, blue: 0.85), Color(red: 0.93, green: 0.85, blue: 0.74)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .widgetURL(entry.character.map { Snapshot.writeURL(for: $0.notebookID, member: $0.id) } ?? Snapshot.writeURL)
        }
        .configurationDisplayName("Write as…")
        .description("Start an entry in a character's voice.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct WriteAsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WriteAsEntry

    private let ink = Color(red: 0.17, green: 0.11, blue: 0.08)
    private let faded = Color(red: 0.42, green: 0.33, blue: 0.26)
    private let ember = Color(red: 0.66, green: 0.27, blue: 0.10)

    private var name: String { entry.character?.name ?? "Your party" }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "pencil.and.scribble")
                    Text(initials)
                        .font(.caption2.weight(.semibold))
                }
            }
            .accessibilityLabel("Write as \(name)")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Write as", systemImage: "pencil.and.scribble")
                    .font(.caption2)
                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                if let notebook = entry.character?.notebookTitle {
                    Text(notebook)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "pencil.and.scribble")
                    .font(.title2)
                    .foregroundStyle(ember)
                Spacer(minLength: 0)
                Text("Write as")
                    .font(.caption)
                    .foregroundStyle(faded)
                Text(name)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                if let character = entry.character {
                    Text(character.notebookTitle)
                        .font(.caption2)
                        .foregroundStyle(faded)
                        .lineLimit(1)
                } else {
                    Text("Add a party member in the app.")
                        .font(.caption2)
                        .foregroundStyle(faded)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var initials: String {
        let words = name.split(separator: " ").filter { $0.first?.isLetter == true }
        let letters = words.count > 1 ? [words.first, words.last] : [words.first]
        return letters.compactMap { $0?.first.map(String.init) }.joined().uppercased()
    }
}

// MARK: Control

/// Control Center and Lock Screen button that opens a new entry (iOS 18).
@available(iOS 18.0, *)
struct WriteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "WriteControl") {
            ControlWidgetButton(action: OpenURLIntent(Snapshot.writeURL)) {
                Label("Write in Journal", systemImage: "pencil.and.scribble")
            }
        }
        .displayName("Write in Journal")
        .description("Open a new journal entry.")
    }
}
