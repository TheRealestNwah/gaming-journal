import SwiftUI
import SwiftData

struct JournalListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlaySession.startDate, order: .reverse) private var sessions: [PlaySession]
    @State private var isAdding = false
    @State private var editing: PlaySession?

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
                            Button { editing = session } label: {
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
                            .tint(.primary)
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
                SessionEditorView()
            }
            .sheet(item: $editing) { session in
                SessionEditorView(session: session)
            }
        }
    }
}

#Preview {
    JournalListView()
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
}
