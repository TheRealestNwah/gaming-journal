import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// A character's journal, read like a book: dated entries on aged pages, turned with the arrows,
/// a swipe or the arrow keys, with a page curl. Tapping an entry opens it to amend. A wide
/// iPad screen shows two facing pages. It opens at the ribbon if one is laid, otherwise on the
/// latest page, where the next entry will go.
struct JournalView: View {
    let journal: Journal

    /// `highlight` is a search query whose words are marked on the page it opens at.
    init(journal: Journal, focusEntryID: UUID? = nil, highlight: String = "") {
        self.journal = journal
        let ribbon = RibbonShelf().mark(for: journal.id)
        _ribbon = State(initialValue: ribbon)
        _anchor = State(initialValue: focusEntryID.map(Anchor.entry) ?? ribbon.map(Anchor.mark) ?? .latest)
        _highlightTerms = State(initialValue: focusEntryID == nil ? [] : EntrySearch.terms(in: highlight))
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 19
    @State private var pageIndex = 0
    /// The page last turned to by the app rather than by a swipe.
    @State private var settledIndex = 0
    @State private var anchor: Anchor
    @State private var textArea = CGSize.zero
    /// The whole screen's size, which decides between one page and two facing pages.
    @State private var screenSize = CGSize.zero
    @State private var hasOpened = false
    @State private var writing: WriterRequest?
    @State private var isEditingJournal = false
    @State private var pendingDelete: Entry?
    @State private var bookExport: ExportDocument?
    @State private var ribbon: RibbonMark?
    @State private var isShowingContents = false
    /// Search words marked on the page a result opened at, until the reader turns away.
    @State private var highlightTerms: [String]
    /// The entry just torn out, while it can still be put back.
    @State private var tornOut: TornOut?
    /// An entry put back by Undo, to turn to once it's in the book again.
    @State private var restoredEntryID: UUID?
    /// An entry drawn as a picture, waiting in the share sheet.
    @State private var sharing: SharedPicture?
    /// The PDF book is being typeset in the background.
    @State private var isBindingBook = false

    private struct SharedPicture: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    private struct TornOut: Equatable {
        let record: JournalBackup.EntryRecord
        let heading: String
    }

    /// The writer, for a new entry or for changing one.
    private struct WriterRequest: Identifiable {
        let entry: Entry?
        var id: UUID { entry?.id ?? Self.newPage }
        static let newPage = UUID()
    }

    /// What the open page follows while the layout settles or changes (size, text size, new
    /// entries): the latest page, the page an entry starts on, the ribbon's page, or wherever the
    /// reader turned to.
    private enum Anchor: Equatable {
        case latest
        case entry(UUID)
        case mark(RibbonMark)
        case free
    }

    private static let pagePadding: CGFloat = 30

    /// 2 when facing pages are open, otherwise 1. `pageIndex` is always the first page of a spread.
    private var perSpread: Int {
        JournalPager.pagesPerSpread(width: screenSize.width, height: screenSize.height)
    }

    private var pages: [JournalPager.Page] {
        let pager = JournalPager(
            width: max(1, textArea.width / Double(perSpread) - Self.pagePadding * 2),
            height: max(1, textArea.height - 16),
            fontSize: fontSize
        )
        return pager.pages(for: journal.story.map { JournalPager.Item(entry: $0) })
    }

    var body: some View {
        // After a delete the view may redraw once more before it's popped; don't touch the model then.
        if journal.isDeleted || journal.modelContext == nil {
            ContentUnavailableView("Journal deleted", systemImage: "trash")
        } else {
            book
        }
    }

    private var book: some View {
        let laidOut = pages
        let entries = Dictionary((journal.entries ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ribbonIndex = ribbonPage(in: laidOut)
        return ZStack(alignment: .bottomTrailing) {
            PaperBackground()
            VStack(spacing: 0) {
                topBar(ribbonIndex: ribbonIndex)
                Text(journal.title)
                    .font(Theme.bookItalic(18, relativeTo: .headline))
                    .foregroundStyle(Theme.fadedInk)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Self.pagePadding)
                    .accessibilityAddTraits(.isHeader)
                PageRule()
                    .padding(.horizontal, Self.pagePadding)
                    .padding(.top, 10)

                ZStack {
                    // Shown once the page size is known, already turned to the right page.
                    if hasOpened {
                        BookPager(
                            spreadCount: spreadCount(laidOut.count),
                            spread: Binding(get: { pageIndex / perSpread }, set: { pageIndex = $0 * perSpread }),
                            curls: !reduceMotion
                        ) { spread in
                            AnyView(spreadView(spread, pages: laidOut, entries: entries, ribbonIndex: ribbonIndex))
                        }
                        // The curl is fixed when the pager is made.
                        .id(reduceMotion)
                        .accessibilityScrollAction { edge in
                            switch edge {
                            case .trailing: turn(to: pageIndex + perSpread)
                            case .leading: turn(to: pageIndex - perSpread)
                            default: break
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear { measured(geometry.size) }
                            .onChange(of: geometry.size) { _, size in measured(size) }
                    }
                }

                bottomBar(pageCount: laidOut.count)
            }
            .frame(maxWidth: perSpread == 2 ? 1280 : 640)
            .frame(maxWidth: .infinity)

            Button {
                writing = WriterRequest(entry: nil)
            } label: {
                WaxSeal()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Write a new entry")
            .keyboardShortcut("n", modifiers: .command)
            .padding(.trailing, 24)
            .padding(.bottom, 70)
        }
        .overlay(alignment: .bottomLeading) {
            if isBindingBook {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Binding the book…")
                        .font(Theme.bookItalic(16, relativeTo: .footnote))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.paperEdge, lineWidth: 1))
                .padding(.leading, 24)
                .padding(.bottom, 76)
                .accessibilityElement(children: .combine)
            } else if let tornOut {
                UndoNote(text: "Torn out: \(tornOut.heading)", onUndo: undoTearOut)
                    .padding(.leading, 24)
                    .padding(.trailing, 110)
                    .padding(.bottom, 76)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .task(id: tornOut) {
                        try? await Task.sleep(for: .seconds(8))
                        guard !Task.isCancelled else { return }
                        self.tornOut = nil
                    }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: tornOut)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { screenSize = geometry.size }
                    .onChange(of: geometry.size) { _, size in screenSize = size }
            }
        }
        .onChange(of: perSpread) {
            if hasOpened { settle() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: laidOut.count) {
            if hasOpened { settle() }
        }
        .onChange(of: pageIndex) { _, index in
            // A swipe: follow the reader from here on.
            if index != settledIndex {
                settledIndex = index
                anchor = index / perSpread == spreadCount(laidOut.count) - 1 ? .latest : .free
                highlightTerms = []
            }
            if UIAccessibility.isVoiceOverRunning {
                AccessibilityNotification.PageScrolled(pageLabel(pageCount: laidOut.count)).post()
            }
        }
        .onChange(of: journal.entries?.count) { oldCount, newCount in
            // Written a new entry: show where it landed. That's usually the last page, but an entry
            // filed under an earlier date goes back among the others.
            if (newCount ?? 0) > (oldCount ?? 0) {
                let newest = (journal.entries ?? []).max { $0.createdAt < $1.createdAt }
                anchor = (restoredEntryID ?? newest?.id).map(Anchor.entry) ?? .latest
                restoredEntryID = nil
                settle(animated: true)
            }
        }
        .sheet(item: $sharing) { shared in
            ShareSheet(items: [shared.image])
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $writing) { request in
            WriterView(journal: journal, entry: request.entry)
        }
        .sheet(isPresented: $isEditingJournal) {
            JournalEditorView(journal: journal)
        }
        .sheet(isPresented: $isShowingContents) {
            let laidOut = pages
            ContentsView(
                entries: journal.story,
                startPages: JournalPager.startPages(in: laidOut),
                ribbonPage: ribbonPage(in: laidOut)
            ) { choice in
                isShowingContents = false
                switch choice {
                case .entry(let id, let query):
                    anchor = .entry(id)
                    highlightTerms = EntrySearch.terms(in: query)
                case .ribbon:
                    highlightTerms = []
                    if let ribbon { anchor = .mark(ribbon) }
                }
                settle(animated: true)
            }
        }
        .confirmationDialog(
            "Tear out this entry?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { entry in
            Button("Delete Entry", role: .destructive) { tearOut(entry) }
        } message: { entry in
            Text("The entry for \(entry.heading()) will be torn out of the journal.")
        }
        .fileExporter(
            isPresented: Binding(get: { bookExport != nil }, set: { if !$0 { bookExport = nil } }),
            document: bookExport,
            // One exporter for both books: SwiftUI honours only one per view.
            contentType: bookExport?.contentType ?? .pdf,
            defaultFilename: bookExport?.filename
        ) { _ in }
    }

    /// The page area was measured: lay out the pages again and keep the book open where it was.
    private func measured(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        textArea = size
        settle()
        hasOpened = true
    }

    /// Turns to the page the anchor asks for. The size can change a few times while the screen
    /// settles, so this runs on every layout change, not just the first.
    private func settle(animated: Bool = false) {
        let pages = pages
        let last = max(0, pages.count - 1)
        let target: Int
        switch anchor {
        case .latest: target = last
        case .entry(let id): target = JournalPager.pageIndex(of: id, in: pages) ?? last
        case .mark(let mark): target = JournalPager.pageIndex(of: mark.entryID, part: mark.part, in: pages) ?? last
        case .free: target = min(pageIndex, last)
        }
        show(JournalPager.spreadStart(of: target, pagesPerSpread: perSpread), animated: animated)
    }

    /// Prev and Next.
    private func turn(to index: Int) {
        let last = JournalPager.spreadStart(of: max(0, laidOutCount - 1), pagesPerSpread: perSpread)
        let target = JournalPager.spreadStart(of: min(max(0, index), last), pagesPerSpread: perSpread)
        anchor = target == last ? .latest : .free
        highlightTerms = []
        show(target, animated: true)
    }

    // MARK: Spreads

    private func spreadCount(_ pageCount: Int) -> Int {
        max(1, (pageCount + perSpread - 1) / perSpread)
    }

    /// "3 of 10", or "3–4 of 10" with facing pages, under the page.
    private func pageNumbers(pageCount: Int) -> String {
        let first = min(pageIndex, max(0, pageCount - 1)) + 1
        let second = min(first + perSpread - 1, pageCount)
        return second > first ? "\(first)–\(second) of \(pageCount)" : "\(first) of \(pageCount)"
    }

    /// "page 3 of 10", or "pages 3–4 of 10" with facing pages, for VoiceOver.
    private func pageLabel(pageCount: Int) -> String {
        let first = min(pageIndex, max(0, pageCount - 1)) + 1
        let second = min(first + perSpread - 1, pageCount)
        return second > first ? "pages \(first)–\(second) of \(pageCount)" : "page \(first) of \(pageCount)"
    }

    /// One spread: a page, or two facing pages with the gutter between them.
    private func spreadView(_ spread: Int, pages: [JournalPager.Page], entries: [UUID: Entry], ribbonIndex: Int?) -> some View {
        let first = spread * perSpread
        return HStack(spacing: 0) {
            ForEach(first..<(first + perSpread), id: \.self) { index in
                if index > first {
                    Rectangle()
                        .fill(Theme.paperEdge.opacity(0.6))
                        .frame(width: 1)
                        .padding(.vertical, 12)
                        .accessibilityHidden(true)
                }
                if pages.indices.contains(index) {
                    PageView(
                        page: pages[index],
                        entries: entries,
                        fontSize: fontSize,
                        highlight: highlightTerms,
                        showsRibbon: ribbonIndex == index
                    ) { entry in
                        writing = WriterRequest(entry: entry)
                    } onDelete: { entry in
                        pendingDelete = entry
                    } onShare: { entry in
                        share(entry)
                    }
                    .padding(.horizontal, Self.pagePadding)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Page \(index + 1)")
                } else {
                    // The blank page facing the last one.
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: Sharing and export

    private func share(_ entry: Entry) {
        guard let image = EntryCard(entry: entry, journal: journal).render() else { return }
        sharing = SharedPicture(image: image)
    }

    /// Typesets the PDF book off the main thread, so a journal full of pictures doesn't freeze
    /// the page while it's bound.
    private func exportPDF() async {
        isBindingBook = true
        defer { isBindingBook = false }
        let book = PDFBook.Book(journal)
        let data = await Task.detached(priority: .userInitiated) { PDFBook.render(book) }.value
        bookExport = ExportDocument(data: data, contentType: .pdf, filename: PDFBook.filename(for: journal))
    }

    // MARK: Tearing out

    /// Deletes an entry, keeping a copy (pictures included) for a few seconds so Undo can put it back.
    private func tearOut(_ entry: Entry) {
        let copy = TornOut(record: JournalBackup.EntryRecord(entry: entry), heading: entry.heading())
        journal.touch()
        context.delete(entry)
        try? context.save()
        tornOut = copy
        AccessibilityNotification.Announcement("Entry torn out. Undo is available.").post()
    }

    private func undoTearOut() {
        guard let tornOut else { return }
        self.tornOut = nil
        let entry = tornOut.record.makeEntry()
        context.insert(entry)
        entry.journal = journal
        journal.touch()
        restoredEntryID = entry.id
        try? context.save()
    }

    private var laidOutCount: Int { pages.count }

    // MARK: Ribbon

    private func ribbonPage(in pages: [JournalPager.Page]) -> Int? {
        ribbon.flatMap { JournalPager.pageIndex(of: $0.entryID, part: $0.part, in: pages) }
    }

    /// Lays the ribbon in the open page, or takes it out with nil.
    private func setRibbon(_ mark: RibbonMark?) {
        ribbon = mark
        RibbonShelf().setMark(mark, for: journal.id)
    }

    private func layRibbonHere() {
        let pages = pages
        guard pages.indices.contains(pageIndex) else { return }
        setRibbon(RibbonMark(page: pages[pageIndex]))
    }

    private func show(_ index: Int, animated: Bool) {
        settledIndex = index
        guard index != pageIndex else { return }
        if animated && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.35)) { pageIndex = index }
        } else {
            pageIndex = index
        }
    }

    // MARK: Bars

    private func topBar(ribbonIndex: Int?) -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Back to journals")
            Spacer()
            Button {
                isShowingContents = true
            } label: {
                Image(systemName: "list.bullet")
                    .accessibilityLabel("Contents")
            }
            .accessibilityIdentifier("contents")
            .padding(.trailing, 14)
            Menu {
                if ribbonIndex.map({ $0 / perSpread }) == pageIndex / perSpread {
                    Button("Take Out the Ribbon", systemImage: "bookmark.slash") { setRibbon(nil) }
                } else {
                    Button("Lay the Ribbon Here", systemImage: "bookmark") { layRibbonHere() }
                        .disabled(journal.entries?.isEmpty ?? true)
                }
                Button("Edit Journal", systemImage: "pencil") { isEditingJournal = true }
                Button("Export as PDF Book", systemImage: "book.closed") {
                    Task { await exportPDF() }
                }
                .disabled(isBindingBook)
                Button("Export as Markdown", systemImage: "doc.text") {
                    bookExport = ExportDocument(
                        data: Data(JournalMarkdown.render(journal).utf8),
                        contentType: .markdownText,
                        filename: JournalMarkdown.filename(for: journal)
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel("Journal options")
            }
        }
        .font(Theme.pageControl)
        .foregroundStyle(Theme.rubric)
        .buttonStyle(.pageControl)
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private func bottomBar(pageCount: Int) -> some View {
        HStack {
            Button { turn(to: pageIndex - perSpread) } label: { Image(systemName: "arrow.left") }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(pageIndex == 0)
                .accessibilityLabel("Previous page")
            Spacer()
            Text(pageNumbers(pageCount: pageCount))
                .font(Theme.bookItalic(15, relativeTo: .footnote))
                .foregroundStyle(Theme.fadedInk)
                .accessibilityLabel(pageLabel(pageCount: pageCount))
            Spacer()
            Button { turn(to: pageIndex + perSpread) } label: { Image(systemName: "arrow.right") }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(pageIndex + perSpread > pageCount - 1)
                .accessibilityLabel("Next page")
        }
        .font(Theme.pageControl)
        .foregroundStyle(Theme.rubric)
        .buttonStyle(.pageControl)
        .padding(.horizontal, 30)
        .padding(.vertical, 12)
    }
}

/// One page of the book.
private struct PageView: View {
    let page: JournalPager.Page
    let entries: [UUID: Entry]
    let fontSize: CGFloat
    let highlight: [String]
    var showsRibbon = false
    let onEdit: (Entry) -> Void
    let onDelete: (Entry) -> Void
    let onShare: (Entry) -> Void

    var body: some View {
        // Scrolls only if the layout estimate ever overfills a page.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if page.blocks.isEmpty {
                    Text("The pages are blank. Take up the quill and write the first entry.")
                        .font(Theme.bookItalic(fontSize))
                        .foregroundStyle(Theme.fadedInk)
                        .padding(.top, 18)
                }
                ForEach(page.blocks) { block in
                    BlockView(block: block, entry: entries[block.entryID], fontSize: fontSize, highlight: highlight)
                        // A tap opens the entry to amend; the long-press menu has the rest.
                        .onTapGesture {
                            if let entry = entries[block.entryID] { onEdit(entry) }
                        }
                        .accessibilityAction {
                            if let entry = entries[block.entryID] { onEdit(entry) }
                        }
                        .accessibilityHint("Opens the entry to amend")
                        .contextMenu {
                            if let entry = entries[block.entryID] {
                                Button("Edit Entry", systemImage: "pencil") { onEdit(entry) }
                                Button("Share as Picture", systemImage: "square.and.arrow.up") { onShare(entry) }
                                Button("Delete Entry", systemImage: "trash", role: .destructive) { onDelete(entry) }
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .overlay(alignment: .topTrailing) {
            if showsRibbon {
                RibbonMarker()
                    .padding(.trailing, 8)
                    .accessibilityLabel("The ribbon marks this page")
            }
        }
    }
}

/// An entry's share of a page: its date where it starts, its words, and its pictures where it ends.
private struct BlockView: View {
    let block: JournalPager.Block
    let entry: Entry?
    let fontSize: CGFloat
    let highlight: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if block.showsHeading {
                Text(marked(block.heading))
                    .font(Theme.dateLine)
                    .foregroundStyle(Theme.rubric)
                    .padding(.top, 18)
                    .accessibilityAddTraits(.isHeader)
                if !block.place.isEmpty {
                    Text(marked(block.place))
                        .font(Theme.bookItalic(fontSize * 0.85))
                        .foregroundStyle(Theme.fadedInk)
                        .accessibilityLabel("At \(block.place)")
                }
            }
            if !block.text.isEmpty {
                Text(marked(block.text))
                    .font(Theme.book(fontSize))
                    .lineSpacing(fontSize * 0.22)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if block.showsPhotos, let entry {
                PhotoStrip(photos: entry.sortedPhotos)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// The text with any search words washed in gilt.
    private func marked(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        for range in EntrySearch.ranges(of: highlight, in: text) {
            if let marked = Range(range, in: attributed) {
                attributed[marked].backgroundColor = Theme.highlight
            }
        }
        return attributed
    }
}

/// A short note after tearing out an entry, with a way to put it back.
private struct UndoNote: View {
    let text: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(text)
                .font(Theme.bookItalic(16, relativeTo: .footnote))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Button("Undo", action: onUndo)
                .font(Theme.pageControl)
                .foregroundStyle(Theme.rubric)
                .keyboardShortcut("z", modifiers: .command)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.paperEdge, lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        .accessibilityElement(children: .combine)
    }
}
