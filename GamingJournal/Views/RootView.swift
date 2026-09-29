import SwiftUI
import SwiftData

/// Top-level tabs.
struct RootView: View {
    @Environment(LiveTimer.self) private var timer
    @State private var tab = RootTab.library
    @State private var isStartingTimer = false
    @AppStorage(OnboardingView.completedKey) private var onboardingCompleted = false
    @State private var writing: WriteRequest?
    @Query(sort: \Notebook.updatedAt, order: .reverse) private var notebooks: [Notebook]

    enum RootTab: Hashable {
        case library, journey, settings
    }

    /// A write link being answered: which notebook, and who's writing if the link said.
    private struct WriteRequest: Identifiable {
        let notebook: Notebook
        let author: PartyMember?
        var id: UUID { notebook.id }
    }

    var body: some View {
        TabView(selection: $tab) {
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(RootTab.library)
            StatsView()
                .tabItem { Label("Journey", systemImage: "map") }
                .tag(RootTab.journey)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(RootTab.settings)
        }
        .foregroundStyle(Theme.ink)
        .background(ParchmentBackground())
        .widgetSync(
            onStartTimer: {
                isStartingTimer = true
            },
            onWrite: { notebookID, memberID in
                tab = .library
                let notebook = notebookID.flatMap { id in notebooks.first { $0.id == id } }
                    ?? notebooks.first { $0.status == .ongoing }
                    ?? notebooks.first
                writing = notebook.map { notebook in
                    WriteRequest(notebook: notebook, author: memberID.flatMap { id in notebook.party.first { $0.id == id } })
                }
            }
        )
        .sheet(item: $writing) { request in
            EntryEditorView(notebook: request.notebook, author: request.author)
        }
        .sheet(isPresented: $isStartingTimer) {
            StartTimerSheet()
                .environment(timer)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !onboardingCompleted },
            set: { if !$0 { onboardingCompleted = true } }
        )) {
            OnboardingView { onboardingCompleted = true }
        }
        .sensoryFeedback(.start, trigger: timer.isActive) { _, isActive in isActive }
    }
}

#Preview {
    RootView()
        .environment(UndoCenter())
        .environment(LiveTimer(defaults: UserDefaults(suiteName: "preview")!))
        .environment(AppLock(defaults: UserDefaults(suiteName: "preview")!))
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
}
