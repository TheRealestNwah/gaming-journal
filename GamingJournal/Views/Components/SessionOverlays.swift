import SwiftUI
import SwiftData

extension View {
    /// Adds the undo toast and the live timer banner along the bottom edge, plus the editor that
    /// opens when the timer is stopped. Apply to each tab's root.
    func sessionOverlays() -> some View {
        modifier(SessionOverlays())
    }
}

private struct SessionOverlays: ViewModifier {
    @Environment(UndoCenter.self) private var undoCenter
    @Environment(LiveTimer.self) private var timer
    @State private var finishedTimer: FinishedTimer?
    @State private var entryPrompt: EntryPrompt?
    @State private var writing: EntryPrompt?
    @Query private var notebooks: [Notebook]

    /// A logged session whose notebook might want an entry about it.
    private struct EntryPrompt: Identifiable {
        let id = UUID()
        let notebook: Notebook
        let startedAt: Date
    }

    /// The session a stopped timer produced, waiting for review in the editor.
    private struct FinishedTimer: Identifiable {
        let id = UUID()
        let draft: SessionDraft
    }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    UndoToastView()
                    TimerBanner { draft in finishedTimer = FinishedTimer(draft: draft) }
                }
                .animation(.spring(duration: 0.3), value: undoCenter.toast)
                .animation(.spring(duration: 0.3), value: timer.state)
            }
            .sheet(item: $finishedTimer) { finished in
                SessionEditorView(prefill: finished.draft) {
                    timer.clear()
                    if let id = finished.draft.notebookID, let notebook = notebooks.first(where: { $0.id == id }) {
                        entryPrompt = EntryPrompt(notebook: notebook, startedAt: finished.draft.startDate)
                    }
                }
            }
            .alert(
                "Write an entry about this session?",
                isPresented: Binding(get: { entryPrompt != nil && finishedTimer == nil }, set: { if !$0 { entryPrompt = nil } }),
                presenting: entryPrompt
            ) { prompt in
                Button("Write") { writing = prompt }
                if CampfireReminders.shared.remindsAfterSessions {
                    Button("Remind me later") {
                        Task {
                            await CampfireReminders.shared.sessionLogged(
                                notebookID: prompt.notebook.id,
                                notebookTitle: prompt.notebook.title
                            )
                        }
                    }
                }
                Button("Not now", role: .cancel) {}
            } message: { prompt in
                Text("Add to \(prompt.notebook.title) while it's fresh.")
            }
            .sheet(item: $writing) { prompt in
                EntryEditorView(
                    notebook: prompt.notebook,
                    prefill: EntryDraft.afterSession(in: prompt.notebook, startedAt: prompt.startedAt)
                )
            }
    }
}
