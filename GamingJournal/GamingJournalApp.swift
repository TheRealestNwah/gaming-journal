import SwiftUI
import SwiftData

@main
struct GamingJournalApp: App {
    var body: some Scene {
        WindowGroup {
            JournalListView()
        }
        .modelContainer(for: JournalEntry.self)
    }
}
