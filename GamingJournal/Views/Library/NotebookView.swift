import SwiftUI
import SwiftData

/// One playthrough: its cover, details and (in later steps) chronicle, party and sessions.
struct NotebookView: View {
    @Environment(\.dismiss) private var dismiss
    let notebook: Notebook
    @State private var isEditing = false
    @State private var selectedMember: PartyMember?

    var body: some View {
        // After a delete the view may redraw once more before it's popped; don't touch the model then.
        if notebook.isDeleted || notebook.modelContext == nil {
            ContentUnavailableView("Notebook deleted", systemImage: "trash")
        } else {
            content
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if !notebook.summary.isEmpty {
                    Text(notebook.summary)
                        .font(Theme.prose)
                        .parchmentCard()
                }
                PartySection(notebook: notebook) { selectedMember = $0 }
                SectionFlourish(title: "Chronicle")
                Text("No entries yet. Soon you'll write here as your party.")
                    .font(Theme.prose)
                    .foregroundStyle(Theme.fadedInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
            .padding()
        }
        .background(ParchmentBackground())
        .navigationTitle(notebook.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { isEditing = true }
        }
        .sheet(isPresented: $isEditing) {
            NotebookEditorView(notebook: notebook)
        }
        .sheet(item: $selectedMember) { member in
            MemberEditorView(notebook: notebook, member: member)
        }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            LeatherCover(title: notebook.title, subtitle: notebook.gameTitle, style: notebook.coverStyle)
                .frame(width: 120)
            VStack(alignment: .leading, spacing: 6) {
                Text(notebook.title)
                    .font(Theme.title(.title2))
                if !notebook.gameTitle.isEmpty {
                    Text([notebook.gameTitle, notebook.platform].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(Theme.fadedInk)
                }
                Label(notebook.status.label, systemImage: notebook.status.systemImage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ember)
                Text("Began \(notebook.startedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(Theme.fadedInk)
            }
        }
    }
}
