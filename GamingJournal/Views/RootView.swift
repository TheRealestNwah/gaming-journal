import SwiftUI

/// Top-level tabs.
struct RootView: View {
    @Environment(LiveTimer.self) private var timer
    @State private var tab = RootTab.library
    @State private var isStartingTimer = false
    @AppStorage(OnboardingView.completedKey) private var onboardingCompleted = false

    enum RootTab: Hashable {
        case library, journal, games, stats, settings
    }

    var body: some View {
        TabView(selection: $tab) {
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(RootTab.library)
            JournalListView()
                .tabItem { Label("Journal", systemImage: "book") }
                .tag(RootTab.journal)
            GamesView()
                .tabItem { Label("Games", systemImage: "square.stack") }
                .tag(RootTab.games)
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(RootTab.stats)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(RootTab.settings)
        }
        .foregroundStyle(Theme.ink)
        .background(ParchmentBackground())
        .widgetSync {
            tab = .journal
            isStartingTimer = true
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
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
}
