import Foundation

/// The closing pages of a finished tale: how long it ran, how it began and ended, the moments that
/// turned it, where each character's feelings went, and the bonds that mattered most.
struct TaleRecap {
    /// One party member's path through the tale.
    struct MemberArc: Identifiable {
        var member: PartyMember
        var entryCount: Int
        /// The feeling that led their first and last felt entries.
        var opening: EmotionGroup?
        var closing: EmotionGroup?
        var mostFelt: Emotion?

        var id: UUID { member.id }

        /// "From Doubt to Resolve", "Held to Warmth", or nil when they never recorded a feeling.
        var journey: String? {
            guard let opening, let closing else { return nil }
            return opening == closing ? "Held to \(opening.label)" : "From \(opening.label) to \(closing.label)"
        }
    }

    var summary: JourneyCalculator.Summary
    var firstEntry: Entry?
    var lastEntry: Entry?
    /// Oldest first, as they happened.
    var turningPoints: [Entry]
    /// Party order; members who never wrote are left out.
    var arcs: [MemberArc]
    /// The strongest feelings between anyone, strongest first.
    var bonds: [CharacterArc.BondSummary]
    /// The family of feelings that ran through the whole tale.
    var prevailingFeeling: EmotionGroup?

    init(notebook: Notebook, calculator: JourneyCalculator = JourneyCalculator(), bondLimit: Int = 3) {
        let story = (notebook.entries ?? []).sorted { ($0.writtenAt, $0.createdAt) < ($1.writtenAt, $1.createdAt) }
        summary = calculator.summary(of: [notebook])
        firstEntry = story.first
        lastEntry = story.count > 1 ? story.last : nil
        turningPoints = story.filter(\.isTurningPoint)
        arcs = notebook.party.compactMap { member in
            let theirs = story.filter { $0.author?.id == member.id }
            guard !theirs.isEmpty else { return nil }
            let points = CharacterArc.points(for: theirs)
            return MemberArc(
                member: member,
                entryCount: theirs.count,
                opening: points.first?.dominant,
                closing: points.last?.dominant,
                mostFelt: CharacterArc.mostFelt(in: theirs, limit: 1).first?.emotion
            )
        }
        bonds = Array(CharacterArc.bonds(in: story).prefix(bondLimit))
        prevailingFeeling = calculator.emotionGroups(in: story).first?.group
    }

    /// Worth showing: something was written.
    var hasStory: Bool { firstEntry != nil }
}
