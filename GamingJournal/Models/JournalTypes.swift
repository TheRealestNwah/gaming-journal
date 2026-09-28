import Foundation

/// Where a playthrough stands.
enum NotebookStatus: String, CaseIterable, Identifiable, Codable {
    case ongoing, completed, abandoned

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ongoing: "Ongoing"
        case .completed: "Completed"
        case .abandoned: "Abandoned"
        }
    }

    var systemImage: String {
        switch self {
        case .ongoing: "flame"
        case .completed: "crown"
        case .abandoned: "moon.zzz"
        }
    }
}

/// A party member's colour, used on their card, avatar and in charts.
enum Sigil: String, CaseIterable, Identifiable, Codable {
    case ember, crimson, gold, forest, frost, arcane, ash

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ember: "Ember"
        case .crimson: "Crimson"
        case .gold: "Gold"
        case .forest: "Forest"
        case .frost: "Frost"
        case .arcane: "Arcane"
        case .ash: "Ash"
        }
    }

    /// sRGB hex, the same in light and dark mode.
    var hex: UInt32 {
        switch self {
        case .ember: 0xD9622B
        case .crimson: 0xB23A48
        case .gold: 0xC9A227
        case .forest: 0x4E7D4F
        case .frost: 0x5B8DB8
        case .arcane: 0x7D5BA6
        case .ash: 0x8A7F76
        }
    }
}

/// Families of feelings; each has its own colour in the emotional-arc chart.
enum EmotionGroup: String, CaseIterable, Identifiable, Codable {
    case resolve, fire, shadow, warmth, doubt

    var id: String { rawValue }

    var label: String {
        switch self {
        case .resolve: "Resolve"
        case .fire: "Fire"
        case .shadow: "Shadow"
        case .warmth: "Warmth"
        case .doubt: "Doubt"
        }
    }

    var hex: UInt32 {
        switch self {
        case .resolve: 0xC9A227
        case .fire: 0xD9622B
        case .shadow: 0x5A4E6B
        case .warmth: 0xC7735A
        case .doubt: 0x7A8C99
        }
    }

    /// Rough emotional tone from −1 (dark) to +1 (bright), for the arc chart's line.
    var valence: Double {
        switch self {
        case .resolve: 0.6
        case .warmth: 1
        case .fire: -0.3
        case .doubt: -0.4
        case .shadow: -1
        }
    }
}

/// The emotions a character can record in an entry.
enum Emotion: String, CaseIterable, Identifiable, Codable {
    case determined, hopeful, proud, curious
    case angry, vengeful, reckless
    case grieving, afraid, guilty, weary
    case joyful, loving, atPeace
    case conflicted, lost

    var id: String { rawValue }

    var group: EmotionGroup {
        switch self {
        case .determined, .hopeful, .proud, .curious: .resolve
        case .angry, .vengeful, .reckless: .fire
        case .grieving, .afraid, .guilty, .weary: .shadow
        case .joyful, .loving, .atPeace: .warmth
        case .conflicted, .lost: .doubt
        }
    }

    var label: String {
        switch self {
        case .determined: "Determined"
        case .hopeful: "Hopeful"
        case .proud: "Proud"
        case .curious: "Curious"
        case .angry: "Angry"
        case .vengeful: "Vengeful"
        case .reckless: "Reckless"
        case .grieving: "Grieving"
        case .afraid: "Afraid"
        case .guilty: "Guilty"
        case .weary: "Weary"
        case .joyful: "Joyful"
        case .loving: "Loving"
        case .atPeace: "At peace"
        case .conflicted: "Conflicted"
        case .lost: "Lost"
        }
    }

    var systemImage: String {
        switch self {
        case .determined: "shield.fill"
        case .hopeful: "sunrise.fill"
        case .proud: "crown.fill"
        case .curious: "magnifyingglass"
        case .angry: "flame.fill"
        case .vengeful: "bolt.fill"
        case .reckless: "tornado"
        case .grieving: "cloud.rain.fill"
        case .afraid: "eye.trianglebadge.exclamationmark.fill"
        case .guilty: "hand.raised.fill"
        case .weary: "moon.zzz.fill"
        case .joyful: "sparkles"
        case .loving: "heart.fill"
        case .atPeace: "leaf.fill"
        case .conflicted: "arrow.triangle.branch"
        case .lost: "questionmark.circle.fill"
        }
    }

    static func inGroup(_ group: EmotionGroup) -> [Emotion] {
        allCases.filter { $0.group == group }
    }
}

/// An emotion felt in an entry, with how strongly (1 faint … 3 overwhelming).
struct FeltEmotion: Codable, Hashable {
    static let intensityRange = 1...3

    var emotionRaw: String
    var intensity: Int

    init(_ emotion: Emotion, intensity: Int = 2) {
        emotionRaw = emotion.rawValue
        self.intensity = min(Self.intensityRange.upperBound, max(Self.intensityRange.lowerBound, intensity))
    }

    /// Nil when the stored emotion no longer exists in this version of the app.
    var emotion: Emotion? { Emotion(rawValue: emotionRaw) }

    /// Clamps intensities and keeps one value per emotion (the last one wins), in first-seen order.
    static func normalized(_ values: [FeltEmotion]) -> [FeltEmotion] {
        var order: [String] = []
        var latest: [String: FeltEmotion] = [:]
        for value in values {
            var clamped = value
            clamped.intensity = min(intensityRange.upperBound, max(intensityRange.lowerBound, value.intensity))
            if latest[value.emotionRaw] == nil { order.append(value.emotionRaw) }
            latest[value.emotionRaw] = clamped
        }
        return order.compactMap { latest[$0] }
    }
}

/// How the writing character feels about someone, recorded in an entry.
struct Bond: Codable, Hashable, Identifiable {
    static let affinityRange = -3...3

    var id: UUID
    /// Another party member, when the bond is with one.
    var targetMemberID: UUID?
    /// Display name: the member's name at the time, or an NPC's name.
    var targetName: String
    /// −3 (hatred) … 0 (neutral) … +3 (devotion).
    var affinity: Int
    var note: String

    init(id: UUID = UUID(), targetMemberID: UUID? = nil, targetName: String, affinity: Int, note: String = "") {
        self.id = id
        self.targetMemberID = targetMemberID
        self.targetName = targetName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.affinity = affinity
        self.note = note
        self = clamped()
    }

    func clamped() -> Bond {
        var copy = self
        copy.affinity = min(Self.affinityRange.upperBound, max(Self.affinityRange.lowerBound, affinity))
        return copy
    }

    var affinityLabel: String {
        switch affinity {
        case ...(-3): "Sworn enemy"
        case -2: "Hostile"
        case -1: "Wary"
        case 0: "Neutral"
        case 1: "Friendly"
        case 2: "Trusted"
        default: "Devoted"
        }
    }
}

/// JSON storage for the small value arrays kept on entries.
enum EntryCoding {
    static func encode<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        guard !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
