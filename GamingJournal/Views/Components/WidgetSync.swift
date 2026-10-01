import SwiftUI
import SwiftData

extension View {
    /// Keeps the widget snapshot and Siri's list of journals current and answers links from
    /// widgets, Siri and reminders. `onWrite` gets the journal a write link names, if any;
    /// `onOpenEntry` gets the entry an "On this day" memory opens.
    func widgetSync(onWrite: @escaping (UUID?) -> Void, onOpenEntry: @escaping (UUID) -> Void) -> some View {
        modifier(WidgetSync(onWrite: onWrite, onOpenEntry: onOpenEntry))
    }
}

private struct WidgetSync: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Entry.writtenAt, order: .reverse) private var entries: [Entry]
    @Query private var journals: [Journal]
    let onWrite: (UUID?) -> Void
    let onOpenEntry: (UUID) -> Void

    /// Changes whenever anything a widget shows might have changed.
    private var fingerprint: [WidgetSnapshot.LatestEntry] {
        entries.filter { $0.journal != nil }.map(WidgetSnapshot.LatestEntry.init(entry:))
    }

    func body(content: Content) -> some View {
        content
            .onAppear(perform: publish)
            .onAppear(perform: saveRoster)
            .onChange(of: QuickWriteRoster(journals: journals)) { saveRoster() }
            .onChange(of: fingerprint) { publish() }
            .onChange(of: scenePhase) { _, phase in
                publish()
            }
            .onOpenURL { url in
                if WidgetSnapshot.isWriteURL(url) {
                    onWrite(WidgetSnapshot.journalID(inWriteURL: url))
                } else if let entryID = WidgetSnapshot.entryID(inEntryURL: url) {
                    onOpenEntry(entryID)
                }
            }
    }

    private func saveRoster() {
        if QuickWriteRoster(journals: journals).save() {
            QuickWriteShortcuts.updateAppShortcutParameters()
        }
    }

    private func publish() {
        // A locked journal keeps its pages off the Home Screen.
        let locked = AppLock.isEnabled()
        let memories = locked ? [] : WidgetSnapshot.memories(from: entries.filter { $0.journal != nil }, today: .now)
        WidgetSnapshot(
            generatedAt: .now,
            latestEntry: locked ? nil : entries.first { $0.journal != nil }.map(WidgetSnapshot.LatestEntry.init(entry:)),
            memories: memories.isEmpty ? nil : memories
        ).publish()
    }
}
