import CoreGraphics
import Foundation

/// What goes on an entry's shareable image card, kept apart from drawing it.
enum ShareCard {
    enum Format: String, CaseIterable, Identifiable {
        case square, story

        var id: String { rawValue }

        var label: String {
            switch self {
            case .square: "Square"
            case .story: "Story"
            }
        }

        /// Pixel size of the exported image.
        var pixelSize: CGSize {
            switch self {
            case .square: CGSize(width: 1080, height: 1080)
            case .story: CGSize(width: 1080, height: 1920)
            }
        }

        /// How much of the entry fits.
        var excerptLimit: Int {
            switch self {
            case .square: 280
            case .story: 700
            }
        }
    }

    struct Content: Equatable {
        var title: String
        var writer: String
        var role: String
        var notebookTitle: String
        var dateLine: String
        var place: String
        var emotions: [Emotion]
        var isTurningPoint: Bool
        /// Nil when the writer chose to keep the text private.
        var excerpt: String?
    }

    static func content(for entry: Entry, format: Format, includesText: Bool, locale: Locale = .current) -> Content {
        var dateStyle = Date.FormatStyle(date: .long, time: .omitted)
        dateStyle.locale = locale
        let realDate = entry.writtenAt.formatted(dateStyle)
        let body = excerpt(entry.body, limit: format.excerptLimit)
        return Content(
            title: entry.title,
            writer: entry.author?.name ?? "Narrator",
            role: entry.author?.role ?? "",
            notebookTitle: entry.notebook?.title ?? "",
            dateLine: entry.inGameDate.isEmpty ? realDate : "\(entry.inGameDate) · \(realDate)",
            place: entry.place,
            emotions: entry.emotions.compactMap(\.emotion),
            isTurningPoint: entry.isTurningPoint,
            excerpt: includesText && !body.isEmpty ? body : nil
        )
    }

    /// The opening of the text up to `limit` characters, cut at a word and marked with "…" when
    /// shortened. Paragraph breaks are kept.
    static func excerpt(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        let cut = trimmed.prefix(limit)
        let wordEnd = cut.lastIndex(where: \.isWhitespace) ?? cut.endIndex
        return cut[..<wordEnd].trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) + "…"
    }

    /// A tidy file name for the image.
    static func filename(for entry: Entry) -> String {
        let base = entry.title.isEmpty ? (entry.notebook?.title ?? "Entry") : entry.title
        let cleaned = base.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined()
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Entry" : cleaned
    }
}
