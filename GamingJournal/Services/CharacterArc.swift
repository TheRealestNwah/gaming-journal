import Foundation

/// How a party member's feelings and relationships change across their entries.
enum CharacterArc {
    /// One entry's emotional tone.
    struct Point: Identifiable, Equatable {
        var id: UUID
        var date: Date
        /// −1 (dark) … +1 (bright): intensity-weighted mean of the felt emotions' group valence.
        var valence: Double
        /// The group felt most strongly in this entry (ties go to the first listed).
        var dominant: EmotionGroup
    }

    struct EmotionWeight: Identifiable, Equatable {
        var emotion: Emotion
        /// Sum of intensities across entries.
        var weight: Int
        var id: Emotion { emotion }
    }

    enum Trend: Equatable {
        case warming, cooling, steady
    }

    /// Where a relationship stands now, and how it got there.
    struct BondSummary: Identifiable, Equatable {
        struct Step: Equatable {
            var date: Date
            var affinity: Int
        }

        /// The party member's ID, or the NPC's normalized name.
        var id: String
        /// Most recent name used.
        var name: String
        var targetMemberID: UUID?
        var history: [Step]
        var latestNote: String

        var affinity: Int { history.last?.affinity ?? 0 }

        var trend: Trend {
            guard history.count > 1 else { return .steady }
            let previous = history[history.count - 2].affinity
            if affinity > previous { return .warming }
            if affinity < previous { return .cooling }
            return .steady
        }
    }

    /// Entry-by-entry tone, oldest first. Entries without recognised emotions are skipped.
    static func points(for entries: [Entry]) -> [Point] {
        entries
            .sorted { ($0.writtenAt, $0.createdAt) < ($1.writtenAt, $1.createdAt) }
            .compactMap { entry in
                let felt = entry.emotions.compactMap { value in value.emotion.map { ($0, value.intensity) } }
                guard !felt.isEmpty else { return nil }
                let total = felt.reduce(0) { $0 + $1.1 }
                let valence = felt.reduce(0.0) { $0 + $1.0.group.valence * Double($1.1) } / Double(total)
                var byGroup: [EmotionGroup: Int] = [:]
                for (emotion, intensity) in felt {
                    byGroup[emotion.group, default: 0] += intensity
                }
                let dominant = EmotionGroup.allCases.max { (byGroup[$0] ?? 0) < (byGroup[$1] ?? 0) } ?? .resolve
                let strongest = EmotionGroup.allCases.first { byGroup[$0] == byGroup[dominant] } ?? dominant
                return Point(id: entry.id, date: entry.writtenAt, valence: valence, dominant: strongest)
            }
    }

    /// Emotions by total intensity, strongest first.
    static func mostFelt(in entries: [Entry], limit: Int = 5) -> [EmotionWeight] {
        var weights: [Emotion: Int] = [:]
        for entry in entries {
            for felt in entry.emotions {
                if let emotion = felt.emotion {
                    weights[emotion, default: 0] += felt.intensity
                }
            }
        }
        let order = Dictionary(uniqueKeysWithValues: Emotion.allCases.enumerated().map { ($1, $0) })
        return weights
            .map { EmotionWeight(emotion: $0.key, weight: $0.value) }
            .sorted { $0.weight != $1.weight ? $0.weight > $1.weight : order[$0.emotion]! < order[$1.emotion]! }
            .prefix(limit)
            .map { $0 }
    }

    /// Relationships recorded in these entries, strongest feelings first.
    static func bonds(in entries: [Entry]) -> [BondSummary] {
        var summaries: [String: BondSummary] = [:]
        let ordered = entries.sorted { ($0.writtenAt, $0.createdAt) < ($1.writtenAt, $1.createdAt) }
        for entry in ordered {
            for bond in entry.bonds {
                let key = bond.targetMemberID?.uuidString ?? ChronicleFilter.normalize(bond.targetName)
                guard !key.isEmpty else { continue }
                var summary = summaries[key]
                    ?? BondSummary(id: key, name: bond.targetName, targetMemberID: bond.targetMemberID, history: [], latestNote: "")
                summary.name = bond.targetName.isEmpty ? summary.name : bond.targetName
                summary.history.append(.init(date: entry.writtenAt, affinity: bond.affinity))
                if !bond.note.isEmpty { summary.latestNote = bond.note }
                summaries[key] = summary
            }
        }
        return summaries.values.sorted {
            abs($0.affinity) != abs($1.affinity) ? abs($0.affinity) > abs($1.affinity) : $0.name < $1.name
        }
    }
}
