import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// A character's journal, read like a book: dated entries on aged pages, turned with Prev and
/// Next or a swipe. It opens on the latest page, where the next entry will go.
struct JournalView: View {
    let journal: Journal
    /// An entry to open at instead of the latest page (from iOS search).
    var focusEntryID: UUID?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 19
    @State private var pageIndex = 0
    @State private var textArea = CGSize.zero
    @State private var hasOpened = false
    @State private var writing: WriterRequest?
    @State private var isEditingJournal = false
    @State private var pendingDelete: Entry?
    @State private var bookExport: ExportDocument?

    /// The writer, for a new entry or for changing one.
    private struct WriterRequest: Identifiable {
        let entry: Entry?
        var id: UUID { entry?.id ?? Self.newPage }
        static let newPage = UUID()
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
        return ZStack(alignment: .bottomTrailing) {
            PaperBackground()
            VStack(spacing: 0) {
                topBar
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
                                PageView(page: page, entries: entries, fontSize: fontSize) { entry in
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
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: laidOut.count) { _, newCount in
            if pageIndex >= newCount {
                pageIndex = max(0, newCount - 1)
            }
        }
        .onChange(of: journal.entries?.count) { oldCount, newCount in
            // Written a new entry: show where it landed, the last page.
            if (newCount ?? 0) > (oldCount ?? 0) { turn(to: pages.count - 1) }
        }
        .fullScreenCover(item: $writing) { request in
            WriterView(journal: journal, entry: request.entry)
        }
        .sheet(isPresented: $isEditingJournal) {
            JournalEditorView(journal: journal)
        }
        .confirmationDialog(
            "Tear out this entry?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { entry in
            Button("Delete Entry", role: .destructive) {
                journal.touch()
                context.delete(entry)
                try? context.save()
            }
        } message: { entry in
            Text("The entry for \(entry.heading()) will be gone for good.")
        }
        .fileExporter(
            isPresented: Binding(get: { bookExport != nil }, set: { if !$0 { bookExport = nil } }),
            document: bookExport,
            // One exporter for both books: SwiftUI honours only one per view.
            contentType: bookExport?.contentType ?? .pdf,
            defaultFilename: bookExport?.filename
        ) { _ in }
    }

    /// The page area was measured: lay out the pages, and on first showing open the book.
    private func measured(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        textArea = size
        if !hasOpened {
            open(in: pages)
        }
    }

    /// First showing: the page with the entry asked for, or else the latest page.
    private func open(in pages: [JournalPager.Page]) {
        hasOpened = true
        if let focusEntryID, let index = JournalPager.pageIndex(of: focusEntryID, in: pages) {
            pageIndex = index
        } else {
            pageIndex = max(0, pages.count - 1)
        }
    }

    private func turn(to index: Int) {
        let target = max(0, index)
        if reduceMotion {
            pageIndex = target
        } else {
            withAnimation(.easeInOut(duration: 0.35)) { pageIndex = target }
        }
    }

    // MARK: Bars

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Text("‹ Journals")
            }
            .accessibilityLabel("Back to journals")
            Spacer()
            Menu {
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
                .disabled(pageIndex == 0)
                .accessibilityLabel("Previous page")
            Spacer()
            Text("page \(min(pageIndex, pageCount - 1) + 1) of \(pageCount)")
                .font(Theme.bookItalic(15, relativeTo: .footnote))
                .foregroundStyle(Theme.fadedInk)
            Spacer()
            Button("Next ›") { turn(to: pageIndex + 1) }
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
                    BlockView(block: block, entry: entries[block.entryID], fontSize: fontSize)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if block.showsHeading {
                Text(block.heading)
                    .font(Theme.dateLine)
                    .foregroundStyle(Theme.rubric)
                    .padding(.top, 18)
                    .accessibilityAddTraits(.isHeader)
            }
            if !block.text.isEmpty {
                Text(block.text)
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
}
