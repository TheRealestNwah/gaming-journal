import SwiftUI
import SwiftData

@main
struct GamingJournalApp: App {
    let container: ModelContainer
    @State private var undoCenter = UndoCenter()

    init() {
        do {
            container = try Persistence.makeContainer()
        } catch {
            fatalError("Could not open the journal store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            JournalListView()
                .environment(undoCenter)
        }
        .modelContainer(container)
    }
}
