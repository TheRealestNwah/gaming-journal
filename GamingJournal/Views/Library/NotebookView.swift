import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// One playthrough: its cover, party, chronicle and atlas.
struct NotebookView: View {
    let notebook: Notebook
    @State private var isEditing = false
    @State private var selectedMember: PartyMember?
    @State private var isWriting = false
    @State private var section = NotebookSection.chronicle
    @State private var filter = ChronicleFilter()
    @State private var bookExport: ExportDocument?
    @State private var pdfExport: ExportDocument?
    @State private var isEditingChapters = false

    enum NotebookSection: String, CaseIterable, Identifiable {
        case chronicle, atlas, sessions

        var id: String { rawValue }

        var label: LocalizedStringKey {
            switch self {
            case .chronicle: "Chronicle"
            case .atlas: "Atlas"
            case .sessions: "Sessions"
            }
        }
    }

    var body: some View {
        // After a delete the view may redraw once more before it's popped; don't touch the model then.
        if notebook.isDeleted || notebook.modelContext == nil {
            ContentUnavailableView("Notebook deleted", systemImage: "trash")
        } else {
            content
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if !notebook.summary.isEmpty {
                    Text(notebook.summary)
                        .font(Theme.prose)
                        .parchmentCard()
                }
                PartySection(notebook: notebook) { selectedMember = $0 }

                Picker("Section", selection: $section) {
                    ForEach(NotebookSection.allCases) { section in
                        Text(section.label).tag(section)
                    }
                }
                .pickerStyle(.segmented)

                switch section {
                case .chronicle:
                    ChronicleSection(notebook: notebook, filter: $filter) { isWriting = true }
                case .atlas:
                    AtlasSection(notebook: notebook) { place in
                        filter = ChronicleFilter(place: place)
                        section = .chronicle
                    }
                case .sessions:
                    NotebookSessionsSection(notebook: notebook)
                }
            }
            .padding()
        }
        .background(ParchmentBackground())
        .navigationTitle(notebook.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Entry.self) { entry in
            EntryDetailView(entry: entry)
        }
        .navigationDestination(for: PlaySession.self) { session in
            SessionDetailView(session: session)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Chapters", systemImage: "bookmark") { isEditingChapters = true }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Export as PDF Book", systemImage: "book.closed") {
                    pdfExport = ExportDocument(
                        data: PDFBook.render(notebook),
                        contentType: .pdf,
                        filename: PDFBook.filename(for: notebook)
                    )
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Export as Markdown", systemImage: "doc.text") {
                    bookExport = ExportDocument(
                        data: Data(NotebookMarkdown.render(notebook).utf8),
                        contentType: .markdownText,
                        filename: NotebookMarkdown.filename(for: notebook)
                    )
                }
            }
        }
        .fileExporter(
            isPresented: Binding(get: { bookExport != nil }, set: { if !$0 { bookExport = nil } }),
            document: bookExport,
            contentType: .markdownText,
            defaultFilename: bookExport?.filename
        ) { _ in }
        .fileExporter(
            isPresented: Binding(get: { pdfExport != nil }, set: { if !$0 { pdfExport = nil } }),
            document: pdfExport,
            contentType: .pdf,
            defaultFilename: pdfExport?.filename
        ) { _ in }
        .sheet(isPresented: $isEditing) {
            NotebookEditorView(notebook: notebook)
        }
        .sheet(isPresented: $isEditingChapters) {
            ChaptersEditorView(notebook: notebook)
        }
        .navigationDestination(item: $selectedMember) { member in
            CharacterSheetView(member: member)
        }
        .sheet(isPresented: $isWriting) {
            EntryEditorView(notebook: notebook)
        }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            LeatherCover(title: notebook.title, subtitle: notebook.gameTitle, style: notebook.coverStyle)
                .frame(width: 120)
            VStack(alignment: .leading, spacing: 6) {
                Text(notebook.title)
                    .font(Theme.title(.title2))
                if !notebook.gameTitle.isEmpty {
                    Text([notebook.gameTitle, notebook.platform].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(Theme.fadedInk)
                }
                Label(notebook.status.label, systemImage: notebook.status.systemImage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ember)
                Text("Began \(notebook.startedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(Theme.fadedInk)
            }
        }
    }
}
