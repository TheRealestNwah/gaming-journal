import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// A character's journal, read like a book: dated entries on aged pages, turned with Prev and
/// Next, a swipe or the arrow keys. It opens at the ribbon if one is laid, otherwise on the latest
/// page, where the next entry will go.
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

    private var pages: [JournalPager.Page] {
        let pager = JournalPager(
            width: max(1, textArea.width - Self.pagePadding * 2),
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
                    // Shown once the page size is known, already turned to the right page:
                    // a paged TabView ignores a jump made while it's first appearing.
                    if hasOpened {
                        TabView(selection: $pageIndex) {
                            ForEach(laidOut) { page in
                                PageView(page: page, entries: entries, fontSize: fontSize, highlight: highlightTerms) { entry in
                                    writing = WriterRequest(entry: entry)
                                } onDelete: { entry in
                                    pendingDelete = entry
                                }
                                .padding(.horizontal, Self.pagePadding)
                                .tag(page.index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
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
                .overlay(alignment: .topTrailing) {
                    if hasOpened && ribbonIndex == pageIndex {
                        RibbonMarker()
                            .padding(.trailing, Self.pagePadding + 8)
                            .offset(y: -11)
                            .accessibilityLabel("The ribbon marks this page")
                    }
                }

                bottomBar(pageCount: laidOut.count)
            }
            .frame(maxWidth: 640)
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
            if let tornOut {
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
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: laidOut.count) {
            if hasOpened { settle() }
        }
        .onChange(of: pageIndex) { _, index in
            // A swipe: follow the reader from here on.
            if index != settledIndex {
                settledIndex = index
                anchor = index == laidOut.count - 1 ? .latest : .free
                highlightTerms = []
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
                case .entry(let id): anchor = .entry(id)
                case .ribbon: if let ribbon { anchor = .mark(ribbon) }
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
        show(target, animated: animated)
    }

    /// Prev and Next.
    private func turn(to index: Int) {
        let last = max(0, laidOutCount - 1)
        let target = min(max(0, index), last)
        anchor = target == last ? .latest : .free
        highlightTerms = []
        show(target, animated: true)
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
                Text("‹ Journals")
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
                if ribbonIndex == pageIndex {
                    Button("Take Out the Ribbon", systemImage: "bookmark.slash") { setRibbon(nil) }
                } else {
                    Button("Lay the Ribbon Here", systemImage: "bookmark") { layRibbonHere() }
                        .disabled(journal.entries?.isEmpty ?? true)
                }
                Button("Edit Journal", systemImage: "pencil") { isEditingJournal = true }
                Button("Export as PDF Book", systemImage: "book.closed") {
                    bookExport = ExportDocument(data: PDFBook.render(journal), contentType: .pdf, filename: PDFBook.filename(for: journal))
                }
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
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private func bottomBar(pageCount: Int) -> some View {
        HStack {
            Button("‹ Prev") { turn(to: pageIndex - 1) }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(pageIndex == 0)
                .accessibilityLabel("Previous page")
            Spacer()
            Text("page \(min(pageIndex, pageCount - 1) + 1) of \(pageCount)")
                .font(Theme.bookItalic(15, relativeTo: .footnote))
                .foregroundStyle(Theme.fadedInk)
            Spacer()
            Button("Next ›") { turn(to: pageIndex + 1) }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(pageIndex >= pageCount - 1)
                .accessibilityLabel("Next page")
        }
        .font(Theme.pageControl)
        .foregroundStyle(Theme.rubric)
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
    let onEdit: (Entry) -> Void
    let onDelete: (Entry) -> Void

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
                        .contextMenu {
                            if let entry = entries[block.entryID] {
                                Button("Edit Entry", systemImage: "pencil") { onEdit(entry) }
                                Button("Delete Entry", systemImage: "trash", role: .destructive) { onDelete(entry) }
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
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
                Text(block.heading)
                    .font(Theme.dateLine)
                    .foregroundStyle(Theme.rubric)
                    .padding(.top, 18)
                    .accessibilityAddTraits(.isHeader)
                if !block.place.isEmpty {
                    Text(block.place)
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
