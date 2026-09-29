import Foundation

/// How a notebook's chapters shape its chronicle, plus the bookkeeping for adding and reordering
/// them.
enum ChapterBook {
    /// A run of the chronicle under one chapter heading. `chapter` is nil for entries that aren't
    /// in any chapter, and for the whole chronicle when the notebook has no chapters.
    struct Part: Identifiable {
        var chapter: Chapter?
        var entries: [Entry]

        var id: String { chapter?.id.uuidString ?? "loose" }
    }

    /// Groups entries (already filtered and sorted newest first) under their chapters. The latest
    /// chapter comes first, matching the newest-first chronicle; entries outside any chapter come
    /// last. Empty chapters are kept only when `includeEmpty` is set, so a filtered chronicle
    /// doesn't show headings with nothing under them.
    static func parts(_ entries: [Entry], chapters: [Chapter], includeEmpty: Bool) -> [Part] {
        guard !chapters.isEmpty else {
            return entries.isEmpty ? [] : [Part(chapter: nil, entries: entries)]
        }
        let known = Set(chapters.map(\.id))
        var byChapter: [UUID: [Entry]] = [:]
        var loose: [Entry] = []
        for entry in entries {
            if let id = entry.chapter?.id, known.contains(id) {
                byChapter[id, default: []].append(entry)
            } else {
                loose.append(entry)
            }
        }
        var parts = chapters.reversed().compactMap { chapter -> Part? in
            let members = byChapter[chapter.id] ?? []
            return members.isEmpty && !includeEmpty ? nil : Part(chapter: chapter, entries: members)
        }
        if !loose.isEmpty {
            parts.append(Part(chapter: nil, entries: loose))
        }
        return parts
    }

    /// Where a newly added chapter goes: after the last one.
    static func nextSortIndex(in notebook: Notebook) -> Int {
        ((notebook.chapters ?? []).map(\.sortIndex).max() ?? -1) + 1
    }

    /// The chapter new entries start in: the last one in story order.
    static func current(in notebook: Notebook) -> Chapter? {
        notebook.orderedChapters.last
    }

    /// Moves chapters like `List.onMove` and renumbers them 0, 1, 2… in the new order.
    static func move(_ chapters: [Chapter], from source: IndexSet, to destination: Int) {
        var ordered = chapters
        let moving = source.map { ordered[$0] }
        for index in source.sorted(by: >) {
            ordered.remove(at: index)
        }
        let insertAt = destination - source.filter { $0 < destination }.count
        ordered.insert(contentsOf: moving, at: min(max(0, insertAt), ordered.count))
        for (index, chapter) in ordered.enumerated() {
            chapter.sortIndex = index
        }
    }

    /// Titles are tidied like other names; a blank title isn't a chapter.
    static func tidyTitle(_ title: String) -> String {
        title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static let untitled = "Untitled chapter"

    /// Tidies titles edited in place, naming any left blank so every heading reads.
    static func tidyTitles(of chapters: [Chapter]) {
        for chapter in chapters {
            let title = tidyTitle(chapter.title)
            chapter.title = title.isEmpty ? untitled : title
            chapter.summary = chapter.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
