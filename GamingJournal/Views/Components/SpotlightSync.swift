import CoreSpotlight
import SwiftData
import SwiftUI

extension View {
    /// Keeps iOS search in step with the journals and opens what a search result points at.
    func spotlightSync() -> some View {
        modifier(SpotlightSync())
    }
}

private struct SpotlightSync: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var journals: [Journal]
    @AppStorage(SpotlightIndex.enabledKey) private var enabled = true
    @State private var opened: Opened?

    /// A search result being shown: a journal, at one entry's page if the result was an entry.
    private struct Opened: Identifiable {
        let id = UUID()
        let journal: Journal
        let entryID: UUID?
    }

    func body(content: Content) -> some View {
        content
            .onAppear(perform: rebuild)
            .onChange(of: enabled) { rebuild() }
            .onChange(of: scenePhase) { _, phase in
                // Catch up on the session's writing as the app leaves the foreground.
                if phase == .background { rebuild() }
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                      let target = SpotlightIndex.Target(identifier: identifier)
                else { return }
                open(target)
            }
            .fullScreenCover(item: $opened) { opened in
                NavigationStack {
                    JournalView(journal: opened.journal, focusEntryID: opened.entryID)
                }
            }
    }

    private func rebuild() {
        SpotlightIndex.rebuild(journals: journals)
    }

    private func open(_ target: SpotlightIndex.Target) {
        switch target {
        case .journal(let id):
            if let journal = journals.first(where: { $0.id == id }) {
                opened = Opened(journal: journal, entryID: nil)
            }
        case .entry(let id):
            if let entry = journals.lazy.flatMap({ $0.entries ?? [] }).first(where: { $0.id == id }), let journal = entry.journal {
                opened = Opened(journal: journal, entryID: entry.id)
            }
        }
    }
}
