import Foundation

/// Where a journal's ribbon lies: the entry on the marked page and which part of it that page
/// holds (0 where the entry starts, 1, 2… as it carries on). Marking the entry rather than a page
/// number keeps the ribbon in place when entries are added or the text size changes.
struct RibbonMark: Codable, Equatable {
    var entryID: UUID
    var part: Int

    /// The ribbon for the page a reader is on, or nil for a blank page.
    init?(page: JournalPager.Page) {
        guard let block = page.blocks.first else { return nil }
        entryID = block.entryID
        part = block.part
    }

    init(entryID: UUID, part: Int) {
        self.entryID = entryID
        self.part = part
    }
}

/// Keeps each journal's ribbon on this device, like the unfinished pages in `DraftShelf`.
struct RibbonShelf {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func key(for journalID: UUID) -> String {
        "ribbon.\(journalID.uuidString)"
    }

    func mark(for journalID: UUID) -> RibbonMark? {
        defaults.data(forKey: Self.key(for: journalID)).flatMap { try? JSONDecoder().decode(RibbonMark.self, from: $0) }
    }

    /// Lays the ribbon at `mark`, or takes it out with nil.
    func setMark(_ mark: RibbonMark?, for journalID: UUID) {
        guard let mark, let data = try? JSONEncoder().encode(mark) else {
            defaults.removeObject(forKey: Self.key(for: journalID))
            return
        }
        defaults.set(data, forKey: Self.key(for: journalID))
    }
}
