import Foundation

/// How a session felt. Stored by raw value on `PlaySession`.
enum Mood: String, CaseIterable, Identifiable, Codable {
    case hyped
    case happy
    case relaxed
    case focused
    case frustrated
    case bored

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hyped: "Hyped"
        case .happy: "Happy"
        case .relaxed: "Relaxed"
        case .focused: "Focused"
        case .frustrated: "Frustrated"
        case .bored: "Bored"
        }
    }

    var emoji: String {
        switch self {
        case .hyped: "🔥"
        case .happy: "😄"
        case .relaxed: "😌"
        case .focused: "🎯"
        case .frustrated: "😤"
        case .bored: "🥱"
        }
    }
}
