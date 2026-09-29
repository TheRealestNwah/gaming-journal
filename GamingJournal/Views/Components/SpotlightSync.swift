import CoreSpotlight
import SwiftData
import SwiftUI

extension View {
    /// Keeps iOS search in step with the journal and opens what a search result points at.
    func spotlightSync() -> some View {
        modifier(SpotlightSync())
    }
}

private struct SpotlightSync: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var notebooks: [Notebook]
    @AppStorage(SpotlightIndex.enabledKey) private var enabled = true
    @State private var opened: Opened?

    /// A search result being shown: a notebook, or one entry.
    private struct Opened: Identifiable {
        let id = UUID()
        let notebook: Notebook?
        let entry: Entry?
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
            .sheet(item: $opened) { opened in
                SearchResultSheet(notebook: opened.notebook, entry: opened.entry)
            }
    }

    private func rebuild() {
        SpotlightIndex.rebuild(notebooks: notebooks)
    }

    private func open(_ target: SpotlightIndex.Target) {
        switch target {
        case .notebook(let id):
            if let notebook = notebooks.first(where: { $0.id == id }) {
                opened = Opened(notebook: notebook, entry: nil)
            }
        case .entry(let id):
            if let entry = notebooks.lazy.flatMap({ $0.entries ?? [] }).first(where: { $0.id == id }) {
                opened = Opened(notebook: entry.notebook, entry: entry)
            }
        }
    }
}

/// A notebook or entry opened from iOS search, over whatever the app was showing.
private struct SearchResultSheet: View {
    @Environment(\.dismiss) private var dismiss
    let notebook: Notebook?
    let entry: Entry?

    var body: some View {
        NavigationStack {
            Group {
                if let entry {
                    EntryDetailView(entry: entry)
                } else if let notebook {
                    NotebookView(notebook: notebook)
                }
            }
            .navigationDestination(for: Entry.self) { entry in
                EntryDetailView(entry: entry)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
