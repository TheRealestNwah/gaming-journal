import SwiftUI
import SwiftData

extension View {
    /// Keeps the widget snapshot current and handles the start-session widget's deep link.
    func widgetSync(onStartTimer: @escaping () -> Void) -> some View {
        modifier(WidgetSync(onStartTimer: onStartTimer))
    }
}

private struct WidgetSync: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(LiveTimer.self) private var timer
    @Query private var sessions: [PlaySession]
    let onStartTimer: () -> Void

    /// Changes whenever anything a widget shows might have changed.
    private var fingerprint: [String] {
        sessions.map { "\($0.id)|\($0.gameTitle)|\($0.platform)|\($0.startDate.timeIntervalSince1970)|\($0.durationMinutes)" }
    }

    func body(content: Content) -> some View {
        content
            .onAppear(perform: publish)
            .onChange(of: fingerprint) { publish() }
            .onChange(of: timer.state) { publish() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { publish() }
            }
            .onOpenURL { url in
                guard url.scheme == WidgetSnapshot.startTimerURL.scheme,
                      url.host == WidgetSnapshot.startTimerURL.host,
                      !timer.isActive
                else { return }
                onStartTimer()
            }
    }

    private func publish() {
        WidgetSnapshot.make(sessions: sessions.map(StatsRecord.init(session:)), timer: timer.state).publish()
    }
}
