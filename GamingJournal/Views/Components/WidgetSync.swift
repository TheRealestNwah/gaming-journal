import SwiftUI
import SwiftData

extension View {
    /// Keeps the widget snapshot and Siri's list of journals current and answers write links
    /// from widgets, Siri and reminders. `onWrite` gets the journal the link names, if any.
    func widgetSync(onWrite: @escaping (UUID?) -> Void) -> some View {
        modifier(WidgetSync(onWrite: onWrite))
    }
}

private struct WidgetSync: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Entry.writtenAt, order: .reverse) private var entries: [Entry]
    @Query private var journals: [Journal]
    let onWrite: (UUID?) -> Void

    /// Changes whenever anything a widget shows might have changed.
    private var fingerprint: [String] {
        entries.prefix(1).map { "\($0.id)|\($0.inGameDate)|\($0.body.prefix(200))|\($0.updatedAt.timeIntervalSince1970)" }
    }

    func body(content: Content) -> some View {
        content
            .onAppear(perform: publish)
            .onAppear(perform: saveRoster)
            .onChange(of: QuickWriteRoster(journals: journals)) { saveRoster() }
            .onChange(of: fingerprint) { publish() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { publish() }
            }
            .onOpenURL { url in
                if WidgetSnapshot.isWriteURL(url) {
                    onWrite(WidgetSnapshot.journalID(inWriteURL: url))
                }
            }
    }

    private func saveRoster() {
        if QuickWriteRoster(journals: journals).save() {
            QuickWriteShortcuts.updateAppShortcutParameters()
        }
    }

    private func publish() {
        WidgetSnapshot(
            generatedAt: .now,
            // A locked journal keeps its pages off the Home Screen.
            latestEntry: AppLock.isEnabled()
                ? nil
                : entries.first { $0.journal != nil }.map(WidgetSnapshot.LatestEntry.init(entry:))
        ).publish()
    }
}
