import CoreSpotlight
import SwiftData
import SwiftUI

extension View {
    /// Keeps iOS search in step with the journals and answers a tapped search result: `onOpen`
    /// gets its journal, and the entry when the result was one.
    func spotlightSync(onOpen: @escaping (Journal, UUID?) -> Void) -> some View {
        modifier(SpotlightSync(onOpen: onOpen))
    }
}

private struct SpotlightSync: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var journals: [Journal]
    @AppStorage(SpotlightIndex.enabledKey) private var enabled = true
    let onOpen: (Journal, UUID?) -> Void

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
    }

    private func rebuild() {
        SpotlightIndex.rebuild(journals: journals)
    }

    private func open(_ target: SpotlightIndex.Target) {
        switch target {
        case .journal(let id):
            if let journal = journals.first(where: { $0.id == id }) {
                onOpen(journal, nil)
            }
        case .entry(let id):
            if let entry = journals.lazy.flatMap({ $0.entries ?? [] }).first(where: { $0.id == id }), let journal = entry.journal {
                onOpen(journal, entry.id)
            }
        }
    }
}
