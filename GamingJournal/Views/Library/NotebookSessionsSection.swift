import SwiftUI
import SwiftData

/// Play time filed under a notebook: start the timer for this playthrough, log a session by hand,
/// and see the sessions so far.
struct NotebookSessionsSection: View {
    @Environment(LiveTimer.self) private var timer
    let notebook: Notebook
    @State private var isLogging = false

    private var sessions: [PlaySession] {
        (notebook.sessions ?? []).sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        let sessions = sessions
        let total = sessions.reduce(0) { $0 + max(0, $1.durationMinutes) }
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    timer.start(gameTitle: notebook.gameTitle.isEmpty ? notebook.title : notebook.gameTitle, notebookID: notebook.id)
                } label: {
                    Label(timer.isActive ? "Timer running" : "Start playing", systemImage: "timer")
                }
                .buttonStyle(.ember)
                .disabled(timer.isActive)

                Button {
                    isLogging = true
                } label: {
                    Label("Log", systemImage: "plus")
                        .font(Theme.heading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(Theme.ember)
                .accessibilityLabel("Log a session")
            }

            if sessions.isEmpty {
                Text("No sessions yet. Start the timer when you pick up the controller.")
                    .font(Theme.prose)
                    .foregroundStyle(Theme.fadedInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                HStack {
                    Label("\(sessions.count) sessions", systemImage: "gamecontroller")
                    Spacer()
                    Label(PlaytimeFormatter.string(fromMinutes: total), systemImage: "hourglass")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.fadedInk)

                LazyVStack(spacing: 10) {
                    ForEach(sessions) { session in
                        NavigationLink(value: session) {
                            SessionRowView(session: session)
                                .parchmentCard(padding: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $isLogging) {
            SessionEditorView(prefill: prefill)
        }
    }

    private var prefill: SessionDraft {
        var draft = SessionDraft()
        draft.gameTitle = notebook.gameTitle
        draft.platform = notebook.platform
        draft.notebookID = notebook.id
        return draft
    }
}
