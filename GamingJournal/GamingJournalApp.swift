import SwiftUI
import SwiftData

@main
struct GamingJournalApp: App {
    let container: ModelContainer
    @State private var undoCenter = UndoCenter()
    @State private var liveTimer: LiveTimer

    init() {
        Theme.applyAppearance()
        do {
            if LaunchOptions.isUITesting {
                // Start each UI test from first launch unless it pre-sets values as launch arguments.
                UserDefaults.standard.removeObject(forKey: OnboardingView.completedKey)
                container = try Persistence.makeContainer(inMemory: true)
                _liveTimer = State(initialValue: LiveTimer(defaults: LaunchOptions.uiTestingDefaults()))
            } else {
                container = try Persistence.makeAppContainer()
                _liveTimer = State(initialValue: LiveTimer())
            }
        } catch {
            fatalError("Could not open the journal store: \(error)")
        }
        if LaunchOptions.seedsDemoData {
            DemoData.sessions().forEach(container.mainContext.insert)
            try? container.mainContext.save()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(undoCenter)
                .environment(liveTimer)
        }
        .modelContainer(container)
    }
}
