import Foundation

/// Launch arguments used by UI tests.
enum LaunchOptions {
    /// In-memory store and throwaway settings, so tests start clean and leave nothing behind.
    static let uiTestingArgument = "-uiTesting"
    /// Seeds a handful of sample sessions (implies nothing else).
    static let demoDataArgument = "-demoData"

    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestingArgument)
    }

    static var seedsDemoData: Bool {
        ProcessInfo.processInfo.arguments.contains(demoDataArgument)
    }

    /// Fresh, empty defaults for a UI-test launch.
    static func uiTestingDefaults() -> UserDefaults {
        let name = "GamingJournal.uiTesting"
        UserDefaults().removePersistentDomain(forName: name)
        return UserDefaults(suiteName: name) ?? .standard
    }
}

/// Sample sessions for UI tests and previews.
enum DemoData {
    static func sessions(now: Date = .now, calendar: Calendar = .current) -> [PlaySession] {
        func daysAgo(_ days: Int, hour: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) ?? now
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        }
        return [
            PlaySession(gameTitle: "Hades", platform: "Switch", startDate: daysAgo(0, hour: 9), durationMinutes: 45,
                        enjoyment: 5, mood: .hyped, notes: "Finally beat the final boss.", tags: ["roguelike"],
                        isMilestone: true, milestoneNote: "First clear"),
            PlaySession(gameTitle: "Celeste", platform: "PC", startDate: daysAgo(1, hour: 20), durationMinutes: 60,
                        enjoyment: 4, mood: .focused, notes: "Chapter 7 is brutal.", tags: ["platformer"]),
            PlaySession(gameTitle: "Hades", platform: "Switch", startDate: daysAgo(2, hour: 21), durationMinutes: 90,
                        enjoyment: 4, mood: .happy, tags: ["roguelike"]),
            PlaySession(gameTitle: "Stardew Valley", platform: "PC", startDate: daysAgo(5, hour: 19), durationMinutes: 120,
                        enjoyment: 5, mood: .relaxed, notes: "Upgraded the house.", tags: ["cozy", "co-op"]),
        ]
    }
}
