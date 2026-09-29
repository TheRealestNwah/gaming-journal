import SwiftUI
import SwiftData

@main
struct GamingJournalApp: App {
    let container: ModelContainer
    @State private var undoCenter = UndoCenter()
    @State private var liveTimer: LiveTimer
    @State private var appLock: AppLock

    init() {
        Theme.applyAppearance()
        do {
            if LaunchOptions.isUITesting {
                // Start each UI test from first launch unless it pre-sets values as launch arguments.
                UserDefaults.standard.removeObject(forKey: OnboardingView.completedKey)
                container = try Persistence.makeContainer(inMemory: true)
                _liveTimer = State(initialValue: LiveTimer(defaults: LaunchOptions.uiTestingDefaults()))
                _appLock = State(initialValue: AppLock(defaults: LaunchOptions.uiTestingDefaults()))
            } else {
                container = try Persistence.makeAppContainer()
                _liveTimer = State(initialValue: LiveTimer())
                _appLock = State(initialValue: AppLock())
            }
        } catch {
            fatalError("Could not open the journal store: \(error)")
        }
        if !LaunchOptions.isUITesting {
            NotificationRouter.shared.install()
            // Keeps the evening reminder in step with Settings, e.g. after a restore.
            Task { await CampfireReminders.shared.applyEveningSetting() }
        }
        if LaunchOptions.seedsDemoData {
            DemoData.seed(into: container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(undoCenter)
                .environment(liveTimer)
                .environment(appLock)
                .appLock(appLock)
        }
        .modelContainer(container)
    }
}
