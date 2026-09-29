import SwiftUI
import SwiftData

extension View {
    /// Keeps the widget snapshot and Siri's roster current and handles the widgets' deep links.
    /// `onWrite` gets the notebook and party member the link names, if any.
    func widgetSync(onStartTimer: @escaping () -> Void, onWrite: @escaping (UUID?, UUID?) -> Void) -> some View {
        modifier(WidgetSync(onStartTimer: onStartTimer, onWrite: onWrite))
    }
}

private struct WidgetSync: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(LiveTimer.self) private var timer
    @Query private var sessions: [PlaySession]
    @Query(sort: \Entry.writtenAt, order: .reverse) private var entries: [Entry]
    @Query private var notebooks: [Notebook]
    let onStartTimer: () -> Void
    let onWrite: (UUID?, UUID?) -> Void

    /// Changes whenever anything a widget shows might have changed.
    private var fingerprint: [String] {
        sessions.map { "\($0.id)|\($0.gameTitle)|\($0.platform)|\($0.startDate.timeIntervalSince1970)|\($0.durationMinutes)" }
            + entries.prefix(1).map { "\($0.id)|\($0.title)|\($0.body.prefix(200))|\($0.updatedAt.timeIntervalSince1970)" }
    }

    func body(content: Content) -> some View {
        content
            .onAppear(perform: publish)
            .onAppear(perform: saveRoster)
            .onChange(of: QuickWriteRoster(notebooks: notebooks)) { saveRoster() }
            .onChange(of: fingerprint) { publish() }
            .onChange(of: timer.state) { publish() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { publish() }
            }
            .onOpenURL { url in
                if url.scheme == WidgetSnapshot.writeURL.scheme, url.host == WidgetSnapshot.writeURL.host {
                    onWrite(WidgetSnapshot.notebookID(inWriteURL: url), WidgetSnapshot.memberID(inWriteURL: url))
                    return
                }
                guard url.scheme == WidgetSnapshot.startTimerURL.scheme,
                      url.host == WidgetSnapshot.startTimerURL.host,
                      !timer.isActive
                else { return }
                onStartTimer()
            }
    }

    private func saveRoster() {
        if QuickWriteRoster(notebooks: notebooks).save() {
            QuickWriteShortcuts.updateAppShortcutParameters()
        }
    }

    private func publish() {
        WidgetSnapshot.make(
            sessions: sessions.map(StatsRecord.init(session:)),
            timer: timer.state,
            // A locked journal keeps its pages off the Home Screen.
            latestEntry: AppLock.isEnabled()
                ? nil
                : entries.first { $0.notebook != nil }.map(WidgetSnapshot.LatestEntry.init(entry:))
        ).publish()
    }
}
