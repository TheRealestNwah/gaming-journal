import SwiftUI
import SwiftData

/// Read-only view of one session with Edit and Delete actions.
struct SessionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(UndoCenter.self) private var undoCenter
    let session: PlaySession
    @State private var isEditing = false

    var body: some View {
        // After a delete the view may redraw once more before it's popped; don't touch the model then.
        if session.isDeleted || session.modelContext == nil {
            ContentUnavailableView("Session deleted", systemImage: "trash")
        } else {
            content
        }
    }

    private var content: some View {
        List {
            Group {
            Section {
                LabeledContent("Game", value: session.gameTitle)
                if !session.platform.isEmpty {
                    LabeledContent("Platform", value: session.platform)
                }
                LabeledContent("Started") {
                    Text(session.startDate, format: .dateTime.weekday(.wide).day().month().year().hour().minute())
                }
                LabeledContent("Played", value: session.formattedDuration)
            }

            if session.enjoyment != nil || session.mood != nil {
                Section("How it felt") {
                    if let enjoyment = session.enjoyment {
                        LabeledContent("Enjoyment") {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { value in
                                    Image(systemName: value <= enjoyment ? "star.fill" : "star")
                                        .foregroundStyle(value <= enjoyment ? Theme.gold : Color.secondary)
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(enjoyment) of 5 stars")
                        }
                    }
                    if let mood = session.mood {
                        LabeledContent("Mood", value: "\(mood.emoji) \(mood.label)")
                    }
                }
            }

            if session.isMilestone {
                Section("Milestone") {
                    HStack(spacing: 10) {
                        WaxSeal(size: 24)
                        Text(session.milestoneNote.isEmpty ? "Milestone" : session.milestoneNote)
                            .font(Theme.heading)
                            .foregroundStyle(Theme.ember)
                    }
                }
            }

            let photos = session.sortedPhotos
            if !photos.isEmpty {
                Section("Photos") {
                    PhotoStrip(photos: photos)
                }
            }

            if !session.notes.isEmpty {
                Section("Notes") {
                    Text(session.notes)
                        .font(Theme.prose)
                        .textSelection(.enabled)
                }
            }

            if !session.tags.isEmpty {
                Section("Tags") {
                    Text(session.tags.map { "#\($0)" }.joined(separator: "  "))
                }
            }

            Section {
                Button("Delete Session", role: .destructive) {
                    dismiss()
                    context.deleteSessions([session], undo: undoCenter)
                }
            }
            }
            .listRowBackground(Theme.vellum)
        }
        .parchmentBackground()
        .navigationTitle(session.gameTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { isEditing = true }
        }
        .sheet(isPresented: $isEditing) {
            SessionEditorView(session: session)
        }
    }
}
