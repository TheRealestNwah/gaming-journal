import Foundation

/// Joins dictated words onto what's already written.
enum DictationText {
    /// Appends `spoken` to `body`: after a space when continuing a line, straight on after a
    /// line break, capitalised when it starts a sentence. Blank dictation changes nothing.
    static func append(_ spoken: String, to body: String) -> String {
        let words = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return body }
        let existing = body.replacingOccurrences(of: "[ \\t]+$", with: "", options: .regularExpression)
        guard let last = existing.last else { return capitalisingFirst(words) }
        if last.isNewline {
            return existing + capitalisingFirst(words)
        }
        let endsSentence = ".!?…".contains(last)
        return existing + " " + (endsSentence ? capitalisingFirst(words) : words)
    }

    private static func capitalisingFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
