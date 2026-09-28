import Foundation

enum PlatformPresets {
    static let all = ["PC", "PS5", "PS4", "Xbox", "Switch", "Steam Deck", "Mobile", "Retro"]

    /// Presets followed by any custom platforms already used, without duplicates.
    static func options(including used: [String]) -> [String] {
        var seen = Set(all.map { $0.lowercased() })
        var result = all
        for platform in used {
            let trimmed = platform.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }
}

enum DurationPresets {
    static let quickMinutes = [15, 30, 60, 120]
}
