import SwiftUI

/// Top-level tabs.
struct RootView: View {
    var body: some View {
        TabView {
            JournalListView()
                .tabItem { Label("Journal", systemImage: "book") }
            GamesView()
                .tabItem { Label("Games", systemImage: "square.stack") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootView()
        .environment(UndoCenter())
        .environment(LiveTimer(defaults: UserDefaults(suiteName: "preview")!))
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
}
