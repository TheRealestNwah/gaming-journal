import SwiftUI

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
                SessionEditorView(prefill: finished.draft) { timer.clear() }
            }
    }
}
