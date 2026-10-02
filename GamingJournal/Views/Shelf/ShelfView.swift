import SwiftUI
import SwiftData

/// Home: every character's journal lying on a dark wood shelf.
struct ShelfView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Journal.updatedAt, order: .reverse) private var journals: [Journal]
    @Binding var path: [JournalRoute]
    @State private var isCreating = false
    @State private var editing: Journal?
    @State private var pendingDelete: Journal?
    @State private var isShowingSettings = false
    @State private var query = ""
    @State private var isSearching = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    if isSearching && !journals.isEmpty {
                        BookSearchField(text: $query, prompt: "Search the journals", onWood: true)
                            .focused($searchFocused)
                            .onAppear { searchFocused = true }
                    }
                    if EntrySearch.terms(in: query).isEmpty {
                        books
                    } else {
                        SearchResults(results: EntrySearch.results(for: query, in: journals), query: query) { result in
                            guard let journal = journals.first(where: { $0.id == result.journalID }) else { return }
                            path.append(JournalRoute(journal: journal, entryID: result.entryID, highlight: query))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: 620)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isSearching)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(WoodBackground())
            .navigationTitle("Journals")
            // Inline, so the hidden principal item replaces the title instead of a large one showing.
            .inlineJournalTitle()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // The shelf's own heading does the job; keep the bar clear.
                    Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if !journals.isEmpty {
                        Button(isSearching ? "Close search" : "Search", systemImage: isSearching ? "xmark" : "magnifyingglass") {
                            toggleSearch()
                        }
                        .keyboardShortcut("f", modifiers: .command)
                    }
                    Button("Begin a new journal", systemImage: "plus") { isCreating = true }
                        .keyboardShortcut("n", modifiers: [.command, .shift])
                    Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
                }
            }
            .tint(Theme.gold)
            .journalNavigationBackground()
            .navigationDestination(for: JournalRoute.self) { route in
                JournalView(journal: route.journal, focusEntryID: route.entryID, highlight: route.highlight)
            }
        }
        .sheet(isPresented: $isCreating) {
            JournalEditorView { journal in path = [JournalRoute(journal: journal)] }
        }
        .sheet(item: $editing) { journal in
            JournalEditorView(journal: journal)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .confirmationDialog(
            "Delete this journal?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { journal in
            Button("Delete \(journal.characterName)'s journal", role: .destructive) {
                path.removeAll { $0.journal.id == journal.id }
                // Its unfinished page and ribbon live outside the store.
                DraftShelf().discard(for: journal.id)
                RibbonShelf().setMark(nil, for: journal.id)
                context.delete(journal)
                try? context.save()
            }
        } message: { _ in
            Text("Every page in it is lost. This can't be undone.")
        }
        #if os(iOS)
        .sensoryFeedback(.success, trigger: journals.count) { old, new in new > old }
        #endif
    }

    /// The journals on the shelf, or a pointer to + when there are none.
    @ViewBuilder
    private var books: some View {
        ForEach(journals) { journal in
            NavigationLink(value: JournalRoute(journal: journal)) {
                ShelfBook(name: journal.characterName, subtitle: journal.subtitle, style: journal.coverStyle)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the journal")
            .contextMenu {
                Button("Edit", systemImage: "pencil") { editing = journal }
                Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = journal }
            }
        }
        if journals.isEmpty {
            Text("Tap + to begin a journal.")
                .font(Theme.bookItalic(18, relativeTo: .body))
                .foregroundStyle(Theme.woodFaded)
                .padding(.top, 24)
        }
    }

    /// Shows the search field, focused, or closes it and clears the search.
    private func toggleSearch() {
        if isSearching {
            query = ""
            isSearching = false
        } else {
            isSearching = true
        }
    }

    private var header: some View {
        Text("Journals")
            .font(Theme.book(40, relativeTo: .largeTitle))
            .foregroundStyle(Theme.woodInk)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 8)
            .padding(.bottom, 6)
    }
}

/// Start a journal, or change an existing one's character, game and cover.
struct JournalEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    private let journal: Journal?
    private let onCreate: ((Journal) -> Void)?
    @State private var characterName: String
    @State private var epithet: String
    @State private var gameTitle: String
    @State private var coverStyle: CoverStyle
    @FocusState private var nameFocused: Bool

    init(journal: Journal? = nil, onCreate: ((Journal) -> Void)? = nil) {
        self.journal = journal
        self.onCreate = onCreate
        _characterName = State(initialValue: journal?.characterName ?? "")
        _epithet = State(initialValue: journal?.epithet ?? "")
        _gameTitle = State(initialValue: journal?.gameTitle ?? "")
        _coverStyle = State(initialValue: journal?.coverStyle ?? .ember)
    }

    private var trimmedName: String {
        characterName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Character's name", text: $characterName)
                        .font(Theme.book(20, relativeTo: .title3))
                        .capitalizedWords()
                        .focused($nameFocused)
                        .accessibilityIdentifier("characterName")
                    TextField("Race, class or title", text: $epithet)
                        .capitalizedWords()
                    TextField("Game", text: $gameTitle)
                        .capitalizedWords()
                } footer: {
                    Text("The journal is written by this character, in their own words.")
                }
                .listRowBackground(Theme.paper.opacity(0.6))

                Section("Cover") {
                    HStack(spacing: 14) {
                        ForEach(CoverStyle.allCases) { style in
                            Button { coverStyle = style } label: {
                                Circle()
                                    .fill(LinearGradient(colors: style.colors, startPoint: .bottomLeading, endPoint: .topTrailing))
                                    .frame(width: 40, height: 40)
                                    .overlay(Circle().strokeBorder(Theme.gold, lineWidth: coverStyle == style ? 3 : 0))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(style.label)
                            .accessibilityAddTraits(coverStyle == style ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Theme.paper.opacity(0.6))
            }
            .scrollContentBackground(.hidden)
            .background(PaperBackground())
            .navigationTitle(journal == nil ? "New Journal" : "Edit Journal")
            .inlineJournalTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(journal == nil ? "Begin" : "Save", systemImage: "checkmark", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear { if journal == nil { nameFocused = true } }
        }
        .tint(Theme.rubric)
        .journalSheetSize()
    }

    private func save() {
        if let journal {
            journal.characterName = trimmedName
            journal.epithet = epithet.trimmingCharacters(in: .whitespacesAndNewlines)
            journal.gameTitle = gameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            journal.coverStyle = coverStyle
            journal.touch()
            try? context.save()
            dismiss()
        } else {
            let journal = Journal(characterName: trimmedName, epithet: epithet, gameTitle: gameTitle, coverStyle: coverStyle)
            context.insert(journal)
            try? context.save()
            dismiss()
            onCreate?(journal)
        }
    }
}

/// A journal to open from the shelf, at one entry's page when a search result points there, with
/// the words searched for marked on it.
struct JournalRoute: Hashable {
    let journal: Journal
    var entryID: UUID?
    var highlight = ""
}

/// Entries matching a search on the shelf. Tapping one opens its journal at that page.
private struct SearchResults: View {
    let results: [EntrySearch.Result]
    let query: String
    let onOpen: (EntrySearch.Result) -> Void

    var body: some View {
        if results.isEmpty {
            Text("No entry speaks of “\(query.trimmingCharacters(in: .whitespaces))”.")
                .font(Theme.bookItalic(18))
                .foregroundStyle(Theme.woodFaded)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(results) { result in
                    Button { onOpen(result) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(result.characterName)
                                    .font(Theme.bookCaps(16, relativeTo: .subheadline))
                                    .foregroundStyle(Theme.gold)
                                Spacer(minLength: 8)
                                Text(result.heading)
                                    .font(Theme.bookItalic(15, relativeTo: .footnote))
                                    .foregroundStyle(Theme.woodFaded)
                                    .multilineTextAlignment(.trailing)
                            }
                            if !result.snippet.isEmpty {
                                Text(result.snippet)
                                    .font(Theme.book(17))
                                    .foregroundStyle(Theme.woodInk)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Opens the journal at this entry")
                    Rectangle()
                        .fill(Theme.gold.opacity(0.25))
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}
