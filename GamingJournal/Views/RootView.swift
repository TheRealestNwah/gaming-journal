import SwiftUI
import SwiftData

/// The shelf of journals, plus what can open over it: a new page from a widget, Siri or a
/// reminder, and the first-launch welcome.
struct RootView: View {
    @AppStorage(OnboardingView.completedKey) private var onboardingCompleted = false
    @Query(sort: \Journal.updatedAt, order: .reverse) private var journals: [Journal]
    @State private var path: [JournalRoute] = []
    @State private var writingIn: Journal?

    var body: some View {
        ShelfView(path: $path)
            // Opened on the shelf's own stack, like an in-app search result, so nothing is
            // presented over it that would block a write link.
            .spotlightSync { journal, entryID in
                path = [JournalRoute(journal: journal, entryID: entryID)]
            }
            .widgetSync { journalID in
                let journal = journalID.flatMap { id in journals.first { $0.id == id } } ?? journals.first
                guard let journal else { return }
                path = [JournalRoute(journal: journal)]
                writingIn = journal
            } onOpenEntry: { entryID in
                guard let journal = journals.first(where: { ($0.entries ?? []).contains { $0.id == entryID } }) else { return }
                path = [JournalRoute(journal: journal, entryID: entryID)]
            }
            .journalCover(item: $writingIn) { journal in
                WriterView(journal: journal)
            }
            .background {
                Color.clear
                    .journalCover(isPresented: Binding(
                        get: { !onboardingCompleted },
                        set: { if !$0 { onboardingCompleted = true } }
                    )) {
                        OnboardingView { onboardingCompleted = true }
                    }
            }
    }
}

#Preview {
    RootView()
        .environment(AppLock(defaults: UserDefaults(suiteName: "preview")!))
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
}
