import SwiftUI
import SwiftData

/// Home: every character's journal lying on a dark wood shelf.
struct ShelfView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Journal.updatedAt, order: .reverse) private var journals: [Journal]
    @Binding var path: [JournalRoute]
    @State private var isCreating = false
    @State private var editing: Journal?
    @State private var pendingDelete: Journal?
    @State private var isShowingSettings = false
    @State private var query = ""

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    if !journals.isEmpty {
                        BookSearchField(text: $query, prompt: "Search the journals", onWood: true)
                    }
                    if EntrySearch.terms(in: query).isEmpty {
                        books
                    } else {
                        SearchResults(results: EntrySearch.results(for: query, in: journals), query: query) { result in
                            guard let journal = journals.first(where: { $0.id == result.journalID }) else { return }
                            path.append(JournalRoute(journal: journal, entryID: result.entryID))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(WoodBackground())
            .navigationTitle("Journals")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // The shelf's own heading does the job; keep the bar clear.
                    Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
                        .tint(Theme.gold)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: JournalRoute.self) { route in
                JournalView(journal: route.journal, focusEntryID: route.entryID)
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
        .sensoryFeedback(.success, trigger: journals.count) { old, new in new > old }
    }

    /// The journals on the shelf, and a place for a new one.
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
        beginButton
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Journals")
                .font(Theme.book(40, relativeTo: .largeTitle))
                .foregroundStyle(Theme.woodInk)
                .accessibilityAddTraits(.isHeader)
            Text(journals.isEmpty ? "Every hero keeps a journal." : "One for every life you've lived.")
                .font(Theme.bookItalic(17, relativeTo: .subheadline))
                .foregroundStyle(Theme.woodFaded)
        }
        .multilineTextAlignment(.center)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var beginButton: some View {
        Button { isCreating = true } label: {
            Label("Begin a new journal", systemImage: "plus")
                .font(Theme.book(20, relativeTo: .headline))
                .foregroundStyle(Theme.gold)
                .frame(maxWidth: .infinity, minHeight: 64)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Theme.gold.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("n", modifiers: [.command, .shift])
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
                        .textInputAutocapitalization(.words)
                        .focused($nameFocused)
                        .accessibilityIdentifier("characterName")
                    TextField("Race, class or title", text: $epithet)
                        .textInputAutocapitalization(.words)
                    TextField("Game", text: $gameTitle)
                        .textInputAutocapitalization(.words)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(journal == nil ? "Begin" : "Save", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear { if journal == nil { nameFocused = true } }
        }
        .tint(Theme.rubric)
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

/// A journal to open from the shelf, at one entry's page when a search result points there.
struct JournalRoute: Hashable {
    let journal: Journal
    var entryID: UUID?
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
