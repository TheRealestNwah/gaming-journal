import SwiftUI
import SwiftData

struct JournalListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No entries yet",
                        systemImage: "gamecontroller",
                        description: Text("Log a play session to start your journal.")
                    )
                } else {
                    List {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.gameTitle).font(.headline)
                                HStack {
                                    Text(entry.date, style: .date)
                                    Text("·")
                                    Text(entry.formattedDuration)
                                    if !entry.platform.isEmpty {
                                        Text("·")
                                        Text(entry.platform)
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                if !entry.notes.isEmpty {
                                    Text(entry.notes).lineLimit(2)
                                }
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { entries[$0] }.forEach(context.delete)
                        }
                    }
                }
            }
            .navigationTitle("Gaming Journal")
            .toolbar {
                Button("Add Entry", systemImage: "plus") { isAdding = true }
            }
            .sheet(isPresented: $isAdding) {
                NewEntryView()
            }
        }
    }
}

struct NewEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var gameTitle = ""
    @State private var platform = ""
    @State private var minutesPlayed = 60
    @State private var notes = ""

    private var trimmedTitle: String {
        gameTitle.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Game", text: $gameTitle)
                TextField("Platform", text: $platform)
                Stepper("Played: \(PlaytimeFormatter.string(fromMinutes: minutesPlayed))",
                        value: $minutesPlayed, in: 0...1440, step: 15)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(JournalEntry(
                            gameTitle: trimmedTitle,
                            platform: platform,
                            minutesPlayed: minutesPlayed,
                            notes: notes
                        ))
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }
}

#Preview {
    JournalListView()
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
