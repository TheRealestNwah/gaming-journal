import SwiftUI
import SwiftData

/// Home: every playthrough notebook as a leather cover on the shelf.
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undoCenter
    @Query(sort: \Notebook.updatedAt, order: .reverse) private var notebooks: [Notebook]
    @State private var isCreating = false
    @State private var editing: Notebook?
    @State private var pendingDelete: Notebook?
    @State private var searchText = ""

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 20)]
    @AppStorage(LibraryShelf.filterKey) private var filter = LibraryShelf.Filter.all
    @AppStorage(LibraryShelf.sortKey) private var sort = LibraryShelf.Sort.lastWritten

    private var shelved: [Notebook] {
        LibraryShelf(filter: filter, sort: sort).arrange(notebooks)
    }

    /// Most recently touched notebook that's still being played.
    private var current: Notebook? {
        notebooks.first { $0.status == .ongoing }
    }

    @Environment(\.horizontalSizeClass) private var sizeClass
    /// The notebook open beside the shelf on iPad.
    @State private var selectedID: UUID?

    private var isSearching: Bool { !ChronicleFilter.normalize(searchText).isEmpty }

    var body: some View {
        Group {
            if sizeClass == .regular {
                splitLibrary
            } else {
                stackLibrary
            }
        }
        .sheet(isPresented: $isCreating) {
            NotebookEditorView()
        }
        .sheet(item: $editing) { notebook in
            NotebookEditorView(notebook: notebook)
        }
        .confirmationDialog(
            "Delete this notebook?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { notebook in
            Button("Delete \(notebook.title)", role: .destructive) {
                if selectedID == notebook.id { selectedID = nil }
                context.deleteNotebook(notebook, undo: undoCenter)
            }
        } message: { _ in
            Text("Its party and every entry go with it. You can undo for a few seconds.")
        }
        .sessionOverlays()
        .sensoryFeedback(.success, trigger: notebooks.count) { old, new in new > old }
    }

    /// iPhone and narrow windows: the shelf, pushing notebooks and entries.
    private var stackLibrary: some View {
        NavigationStack {
            Group {
                if notebooks.isEmpty {
                    emptyShelf
                } else if isSearching {
                    LibrarySearchResults(query: searchText, notebooks: notebooks)
                } else {
                    shelf
                }
            }
            .background {
                ZStack(alignment: .bottom) {
                    ParchmentBackground()
                    EmberField(count: notebooks.isEmpty ? 24 : 10)
                        .frame(height: 320)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: Notebook.self) { notebook in
                NotebookView(notebook: notebook)
            }
            // Declared once at the root so both a notebook's chronicle and search can open entries.
            .navigationDestination(for: Entry.self) { entry in
                EntryDetailView(entry: entry)
            }
            .searchable(text: $searchText, prompt: "Search every tale")
            .toolbar { libraryToolbar }
        }
    }

    /// iPad: the shelf as a sidebar, with the chosen notebook (or search results) beside it.
    /// Entries open within the notebook's column.
    private var splitLibrary: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                ForEach(shelved) { notebook in
                    SidebarRow(notebook: notebook)
                        .tag(notebook.id)
                        .contextMenu { notebookMenu(notebook) }
                }
            }
            .overlay {
                if notebooks.isEmpty {
                    ContentUnavailableView("The shelf is bare", systemImage: "book.closed", description: Text("Begin a new tale to start writing."))
                } else if shelved.isEmpty {
                    ContentUnavailableView("No \(filter.label.lowercased()) tales", systemImage: "books.vertical")
                }
            }
            .scrollContentBackground(.hidden)
            .background(ParchmentBackground())
            .navigationTitle("Library")
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search every tale")
            .toolbar { libraryToolbar }
        } detail: {
            NavigationStack {
                Group {
                    if isSearching {
                        LibrarySearchResults(query: searchText, notebooks: notebooks)
                    } else if let notebook = notebooks.first(where: { $0.id == selectedID }) {
                        NotebookView(notebook: notebook)
                            .id(notebook.id)
                    } else if notebooks.isEmpty {
                        emptyShelf
                    } else {
                        ContentUnavailableView("Choose a tale", systemImage: "books.vertical", description: Text("Pick a notebook from the shelf to read and write in it."))
                    }
                }
                .background(ParchmentBackground())
                .navigationDestination(for: Notebook.self) { notebook in
                    NotebookView(notebook: notebook)
                }
                .navigationDestination(for: Entry.self) { entry in
                    EntryDetailView(entry: entry)
                }
            }
        }
        .onAppear {
            if selectedID == nil { selectedID = current?.id }
        }
    }

    @ToolbarContentBuilder
    private var libraryToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("New Notebook", systemImage: "plus") { isCreating = true }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        if !notebooks.isEmpty {
            ToolbarItem(placement: .topBarLeading) {
                shelfMenu
            }
        }
    }

    /// Pin, edit, change status or delete: the same on the shelf and in the sidebar.
    @ViewBuilder
    private func notebookMenu(_ notebook: Notebook) -> some View {
        Button(notebook.isPinned ? "Unpin" : "Pin to Top", systemImage: notebook.isPinned ? "pin.slash" : "pin") {
            withAnimation { notebook.isPinned.toggle() }
        }
        Button("Edit", systemImage: "pencil") { editing = notebook }
        Menu("Status", systemImage: "flag") {
            ForEach(NotebookStatus.allCases) { status in
                Button(status.label, systemImage: status.systemImage) {
                    notebook.status = status
                    notebook.touch()
                }
            }
        }
        Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = notebook }
    }

    private var emptyShelf: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "book.closed.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.ember)
                .accessibilityHidden(true)
            Text("The shelf is bare")
                .font(Theme.title(.title2))
            Text("Every tale starts with a blank page. Start a notebook for your playthrough, gather your party and write their story as you play.")
                .font(Theme.prose)
                .foregroundStyle(Theme.fadedInk)
                .multilineTextAlignment(.center)
            Button("Begin a new tale") { isCreating = true }
                .buttonStyle(.ember)
                .frame(maxWidth: 320)
            Spacer()
        }
        .padding(32)
    }

    private var shelf: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let current {
                    ContinueCard(notebook: current)
                }
                SectionFlourish(title: filter == .all ? "Your notebooks" : filter.label)
                if shelved.isEmpty {
                    VStack(spacing: 8) {
                        Text("No \(filter.label.lowercased()) tales on the shelf.")
                            .font(Theme.prose)
                            .foregroundStyle(Theme.fadedInk)
                        Button("Show all tales") { filter = .all }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(shelved) { notebook in
                        NavigationLink(value: notebook) {
                            ShelfCover(notebook: notebook)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { notebookMenu(notebook) }
                    }
                }
            }
            .padding()
        }
    }
}

extension LibraryView {
    /// Filter and sort for the shelf.
    private var shelfMenu: some View {
        Menu {
            Picker("Show", selection: $filter) {
                ForEach(LibraryShelf.Filter.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            Picker("Sort by", selection: $sort) {
                ForEach(LibraryShelf.Sort.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
        } label: {
            Label("Sort and Filter", systemImage: filter == .all
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
    }
}

/// A notebook in the iPad sidebar: a small cover, its title, game and status.
private struct SidebarRow: View {
    let notebook: Notebook

    var body: some View {
        HStack(spacing: 12) {
            LeatherCover(title: "", style: notebook.coverStyle)
                .frame(width: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(notebook.title)
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .lineLimit(2)
                    if notebook.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.gold)
                            .accessibilityLabel("Pinned")
                    }
                }
                Text([notebook.gameTitle, notebook.status.label].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.fadedInk)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// A cover on the shelf with the notebook's status underneath.
private struct ShelfCover: View {
    let notebook: Notebook

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LeatherCover(title: notebook.title, subtitle: notebook.gameTitle, style: notebook.coverStyle)
                .overlay(alignment: .topTrailing) {
                    if notebook.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.gold)
                            .padding(8)
                            .accessibilityLabel("Pinned")
                    }
                }
            HStack(spacing: 4) {
                Image(systemName: notebook.status.systemImage)
                Text(notebook.status.label)
                Spacer(minLength: 4)
                Text("\(notebook.entries?.count ?? 0) entries")
            }
            .font(.caption)
            .foregroundStyle(Theme.fadedInk)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the notebook")
    }
}

/// "Continue your tale": the current playthrough with its latest entry.
private struct ContinueCard: View {
    let notebook: Notebook

    var body: some View {
        NavigationLink(value: notebook) {
            HStack(alignment: .top, spacing: 16) {
                LeatherCover(title: notebook.title, style: notebook.coverStyle)
                    .frame(width: 84)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Continue your tale")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(Theme.ember)
                    Text(notebook.title)
                        .font(Theme.title(.title3))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    if let latest = notebook.chronicle.first {
                        Text(latest.title.isEmpty ? latest.body : latest.title)
                            .font(Theme.prose)
                            .foregroundStyle(Theme.fadedInk)
                            .lineLimit(2)
                        Text(latest.writtenAt, format: .relative(presentation: .named))
                            .font(.caption)
                            .foregroundStyle(Theme.fadedInk)
                    } else {
                        Text("No entries yet. The first page is waiting.")
                            .font(Theme.prose)
                            .foregroundStyle(Theme.fadedInk)
                    }
                }
                Spacer(minLength: 0)
            }
            .parchmentCard()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LibraryView()
        .environment(UndoCenter())
        .environment(LiveTimer(defaults: UserDefaults(suiteName: "preview")!))
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
}
