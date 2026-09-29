import Foundation
import SwiftData

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

/// Sample data for UI tests and previews.
enum DemoData {
    /// Inserts the sample notebook (with its party, entries and a session) and loose sessions.
    @MainActor
    static func seed(into context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        sessions(now: now, calendar: calendar).forEach(context.insert)
        let notebook = self.notebook(now: now, calendar: calendar)
        context.insert(notebook)
        let session = PlaySession(gameTitle: "Skyrim", platform: "PC",
                                  startDate: now.addingTimeInterval(-3 * 3600), durationMinutes: 110)
        context.insert(session)
        session.notebook = notebook
        try? context.save()
    }

    /// "The Dragonborn's Road": two companions and a few entries with feelings, places and bonds.
    static func notebook(now: Date = .now, calendar: Calendar = .current) -> Notebook {
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: now) ?? now
        }
        let notebook = Notebook(
            title: "The Dragonborn's Road",
            gameTitle: "Skyrim",
            platform: "PC",
            coverStyle: .ember,
            startedAt: daysAgo(10),
            summary: "A prisoner at Helgen, a dragon overhead, and a road north."
        )
        let lydia = PartyMember(name: "Lydia", role: "Housecarl", backstory: "Sworn to carry your burdens.",
                                sigil: .gold, sortIndex: 0)
        let serana = PartyMember(name: "Serana", role: "Vampire", backstory: "Woke after centuries in a tomb.",
                                 sigil: .crimson, sortIndex: 1)
        notebook.members = [lydia, serana]

        let first = Entry(title: "Smoke over Helgen", body: "The dragon came out of nowhere. I still smell ash.",
                          writtenAt: daysAgo(9), place: "Helgen", quest: "Unbound",
                          emotions: [FeltEmotion(.afraid, intensity: 3), FeltEmotion(.determined, intensity: 1)])
        first.author = lydia
        let second = Entry(title: "The Bannered Mare", body: "A warm fire, a loud bard and, for once, sleep.",
                           writtenAt: daysAgo(6), place: "Whiterun",
                           emotions: [FeltEmotion(.atPeace, intensity: 2)],
                           bonds: [Bond(targetMemberID: serana.id, targetName: "Serana", affinity: 1, note: "Strange, but kind")])
        second.author = lydia
        let third = Entry(title: "What I am", body: "I told them what I am. Lydia didn't flinch.",
                          writtenAt: daysAgo(2), place: "Dawnguard", isTurningPoint: true,
                          emotions: [FeltEmotion(.conflicted, intensity: 2), FeltEmotion(.hopeful, intensity: 2)],
                          bonds: [Bond(targetMemberID: lydia.id, targetName: "Lydia", affinity: 2)])
        third.author = serana
        let fourth = Entry(title: "Trust", body: "She saved my life at Fort Dawnguard.",
                           writtenAt: daysAgo(1), place: "Dawnguard",
                           emotions: [FeltEmotion(.proud, intensity: 2), FeltEmotion(.loving, intensity: 1)],
                           bonds: [Bond(targetMemberID: serana.id, targetName: "Serana", affinity: 3, note: "Saved my life")])
        fourth.author = lydia
        notebook.entries = [first, second, third, fourth]
        notebook.updatedAt = now
        return notebook
    }

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
