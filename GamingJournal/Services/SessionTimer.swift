import Foundation
import Observation

/// A running or paused play timer. Plain value so it can be persisted and tested.
struct TimerState: Codable, Equatable {
    var gameTitle: String
    /// When the timer was first started; becomes the session's start date.
    var startedAt: Date
    /// Seconds counted in earlier runs, before the current one.
    var accumulated: TimeInterval = 0
    /// Start of the current run, or nil while paused.
    var runningSince: Date?

    init(gameTitle: String, startedAt: Date) {
        self.gameTitle = gameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.startedAt = startedAt
        self.runningSince = startedAt
    }

    var isPaused: Bool { runningSince == nil }

    func elapsed(at now: Date) -> TimeInterval {
        let current = runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0
        return max(0, accumulated + current)
    }

    mutating func pause(at now: Date) {
        guard runningSince != nil else { return }
        accumulated = elapsed(at: now)
        runningSince = nil
    }

    mutating func resume(at now: Date) {
        guard runningSince == nil else { return }
        runningSince = now
    }

    /// Elapsed time rounded to the nearest minute; any time at all counts as at least one minute.
    func minutes(at now: Date) -> Int {
        let seconds = elapsed(at: now)
        guard seconds > 0 else { return 0 }
        return max(1, Int((seconds / 60).rounded()))
    }

    /// Editor prefill for the finished session.
    func draft(at now: Date) -> SessionDraft {
        var draft = SessionDraft()
        draft.gameTitle = gameTitle
        draft.startDate = startedAt
        draft.durationMinutes = minutes(at: now)
        return draft
    }
}

/// The app's single live timer, persisted to `UserDefaults` so it survives the app being killed.
@Observable
@MainActor
final class LiveTimer {
    static let defaultsKey = "liveTimer.state"

    private(set) var state: TimerState? {
        didSet { persist() }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.state = defaults.data(forKey: Self.defaultsKey)
            .flatMap { try? JSONDecoder().decode(TimerState.self, from: $0) }
    }

    var isActive: Bool { state != nil }

    func start(gameTitle: String, at now: Date = .now) {
        state = TimerState(gameTitle: gameTitle, startedAt: now)
    }

    func pause(at now: Date = .now) {
        state?.pause(at: now)
    }

    func resume(at now: Date = .now) {
        state?.resume(at: now)
    }

    /// Pauses the timer and returns the session to review. The timer stays until `clear()`, so
    /// cancelling the editor doesn't lose the time.
    func stop(at now: Date = .now) -> SessionDraft? {
        pause(at: now)
        return state?.draft(at: now)
    }

    func clear() {
        state = nil
    }

    private func persist() {
        if let state, let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Self.defaultsKey)
        } else {
            defaults.removeObject(forKey: Self.defaultsKey)
        }
    }
}
