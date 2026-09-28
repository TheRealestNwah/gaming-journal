import SwiftUI
import SwiftData

struct JournalListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlaySession.startDate, order: .reverse) private var sessions: [PlaySession]
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "gamecontroller",
                        description: Text("Log a play session to start your journal.")
                    )
                } else {
                    List {
                        ForEach(sessions) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.gameTitle).font(.headline)
                                HStack {
                                    Text(session.startDate, style: .date)
                                    Text("·")
                                    Text(session.formattedDuration)
                                    if !session.platform.isEmpty {
                                        Text("·")
                                        Text(session.platform)
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                if !session.notes.isEmpty {
                                    Text(session.notes).lineLimit(2)
                                }
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { sessions[$0] }.forEach(context.delete)
                        }
                    }
                }
            }
            .navigationTitle("Gaming Journal")
            .toolbar {
                Button("Add Session", systemImage: "plus") { isAdding = true }
            }
            .sheet(isPresented: $isAdding) {
                NewSessionView()
            }
        }
    }
}

struct NewSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var gameTitle = ""
    @State private var platform = ""
    @State private var durationMinutes = 60
    @State private var notes = ""

    private var trimmedTitle: String {
        gameTitle.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Game", text: $gameTitle)
                TextField("Platform", text: $platform)
                Stepper("Played: \(PlaytimeFormatter.string(fromMinutes: durationMinutes))",
                        value: $durationMinutes, in: 0...1440, step: 15)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }
            .navigationTitle("New Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(PlaySession(
                            gameTitle: trimmedTitle,
                            platform: platform,
                            durationMinutes: durationMinutes,
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
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
}
