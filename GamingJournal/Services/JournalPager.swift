import Foundation

/// Lays a journal's entries out on book pages. Space is measured in lines of roughly
/// `charactersPerLine` characters, so pages fill like a printed book: an entry that doesn't fit
/// carries on over the page, and a date heading is never left alone at the foot of a page.
struct JournalPager {
    /// What goes onto the pages, in reading order.
    struct Item: Equatable {
        var id: UUID
        var heading: String
        /// Shown under the heading; empty when the entry names no place.
        var place: String = ""
        var body: String
        var hasPhotos: Bool
    }

    /// One entry's share of a page.
    struct Block: Equatable, Identifiable {
        var entryID: UUID
        /// 0 for where the entry starts, then 1, 2… as it carries on over pages.
        var part: Int
        /// The date heading shows where the entry starts, not where it carries on.
        var showsHeading: Bool
        var heading: String
        var place: String
        var text: String
        /// The entry's pictures follow its last words.
        var showsPhotos: Bool

        var id: String { "\(entryID)-\(part)" }
    }

    struct Page: Equatable, Identifiable {
        /// 0-based position in the book.
        var index: Int
        var blocks: [Block]

        var id: Int { index }
    }

    /// Lines a date heading takes, with the space above it.
    static let headingLines = 2
    /// The extra line a place under the heading takes.
    static let placeLines = 1
    /// Extra lines between entries; the heading's own space already separates them.
    static let entryGap = 0
    /// Lines a row of photo thumbnails takes.
    static let photoLines = 5

    var charactersPerLine: Int
    var linesPerPage: Int

    init(charactersPerLine: Int, linesPerPage: Int) {
        self.charactersPerLine = max(8, charactersPerLine)
        // Room for at least a heading, a little text and the photos.
        self.linesPerPage = max(Self.headingLines + Self.photoLines + 2, linesPerPage)
    }

    /// Estimates line capacity from the page's text area and the body font size.
    init(width: Double, height: Double, fontSize: Double) {
        // Slightly generous per-character and per-line sizes for IM Fell with the page's line
        // spacing, so an estimate fills a page without overfilling it.
        self.init(
            charactersPerLine: Int(width / (fontSize * 0.48)),
            linesPerPage: Int(height / (fontSize * 1.42))
        )
    }

    /// The pages for `items`; always at least one, so an empty journal still opens on a page.
    func pages(for items: [Item]) -> [Page] {
        var pages: [Page] = []
        var blocks: [Block] = []
        var used = 0

        func turnPage() {
            pages.append(Page(index: pages.count, blocks: blocks))
            blocks = []
            used = 0
        }

        for item in items {
            let paragraphs = Self.paragraphs(in: item.body)
            // Keep the heading with at least a couple of lines of what follows, or with the
            // pictures when there are no words.
            let keptLines = paragraphs.first.map { min(2, lineCount(of: $0)) } ?? (item.hasPhotos ? Self.photoLines : 0)
            let gap = blocks.isEmpty ? 0 : Self.entryGap
            let headingLines = Self.headingLines + (item.place.isEmpty ? 0 : Self.placeLines)
            if !blocks.isEmpty && used + gap + headingLines + keptLines > linesPerPage {
                turnPage()
            }
            used += (blocks.isEmpty ? 0 : Self.entryGap) + headingLines

            var showsHeading = true
            var part = 0
            var pieces: [String] = []

            func placeBlock(showsPhotos: Bool) {
                blocks.append(Block(
                    entryID: item.id,
                    part: part,
                    showsHeading: showsHeading,
                    heading: item.heading,
                    place: item.place,
                    text: pieces.joined(separator: "\n"),
                    showsPhotos: showsPhotos
                ))
                showsHeading = false
                part += 1
                pieces = []
            }

            for paragraph in paragraphs {
                var lines = wrap(paragraph)
                while !lines.isEmpty {
                    let available = linesPerPage - used
                    if lines.count <= available {
                        pieces.append(lines.joined(separator: " "))
                        used += lines.count
                        lines = []
                    } else {
                        if available > 0 {
                            pieces.append(lines.prefix(available).joined(separator: " "))
                            lines.removeFirst(available)
                        }
                        if !pieces.isEmpty || showsHeading {
                            placeBlock(showsPhotos: false)
                        }
                        turnPage()
                    }
                }
            }

            if item.hasPhotos && used + Self.photoLines > linesPerPage {
                if !pieces.isEmpty || showsHeading {
                    placeBlock(showsPhotos: false)
                }
                turnPage()
            }
            if item.hasPhotos {
                used += Self.photoLines
            }
            if !pieces.isEmpty || showsHeading || item.hasPhotos {
                placeBlock(showsPhotos: item.hasPhotos)
            }
        }

        if !blocks.isEmpty || pages.isEmpty {
            turnPage()
        }
        return pages
    }

    /// The page an entry starts on.
    static func pageIndex(of entryID: UUID, in pages: [Page]) -> Int? {
        pages.first { page in page.blocks.contains { $0.entryID == entryID } }?.index
    }

    /// The page holding part `part` of an entry. If the entry now runs to fewer parts (a larger
    /// text size, say), the page holding its last part.
    static func pageIndex(of entryID: UUID, part: Int, in pages: [Page]) -> Int? {
        pages.last { page in page.blocks.contains { $0.entryID == entryID && $0.part <= part } }?.index
    }

    /// The page each entry starts on, for a table of contents.
    static func startPages(in pages: [Page]) -> [UUID: Int] {
        var starts: [UUID: Int] = [:]
        for page in pages {
            for block in page.blocks where starts[block.entryID] == nil {
                starts[block.entryID] = page.index
            }
        }
        return starts
    }

    // MARK: Measuring

    static func paragraphs(in text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func lineCount(of paragraph: String) -> Int {
        wrap(paragraph).count
    }

    /// Greedy word wrap into lines of at most `charactersPerLine` characters. A word longer than a
    /// line is broken across lines.
    func wrap(_ paragraph: String) -> [String] {
        var lines: [String] = []
        var line = ""
        for word in paragraph.split(whereSeparator: \.isWhitespace).map(String.init) {
            var word = word
            while word.count > charactersPerLine {
                if !line.isEmpty {
                    lines.append(line)
                    line = ""
                }
                lines.append(String(word.prefix(charactersPerLine)))
                word = String(word.dropFirst(charactersPerLine))
            }
            if line.isEmpty {
                line = word
            } else if line.count + 1 + word.count <= charactersPerLine {
                line += " " + word
            } else {
                lines.append(line)
                line = word
            }
        }
        if !line.isEmpty {
            lines.append(line)
        }
        return lines
    }
}

extension JournalPager.Item {
    init(entry: Entry, locale: Locale = .current) {
        id = entry.id
        heading = entry.heading(locale: locale)
        place = entry.place
        body = entry.body
        hasPhotos = !(entry.photos ?? []).isEmpty
    }
}
