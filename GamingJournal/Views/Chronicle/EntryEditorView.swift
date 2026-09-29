import SwiftUI
import SwiftData

/// Write or edit an entry in a notebook, in a party member's voice.
struct EntryEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let notebook: Notebook
    private let entry: Entry?
    @State private var draft: EntryDraft
    @State private var showsDetails: Bool
    @FocusState private var focusedField: Field?
    @AppStorage(WritingPrompts.enabledKey) private var promptsEnabled = true
    @State private var promptDismissed = false

    private enum Field { case title, body, place, quest }

    init(notebook: Notebook, entry: Entry? = nil, author: PartyMember? = nil, prefill: EntryDraft? = nil) {
        self.notebook = notebook
        self.entry = entry
        let initial = entry.map(EntryDraft.init(entry:))
            ?? prefill
            ?? EntryDraft(authorID: author?.id ?? notebook.party.first(where: { !$0.isRetired })?.id)
        _draft = State(initialValue: initial)
        _showsDetails = State(initialValue: !(initial.place.isEmpty && initial.quest.isEmpty && initial.inGameDate.isEmpty))
    }

    private var entries: [Entry] { notebook.entries ?? [] }

    /// Prompts appear on a fresh entry until the writer starts, uses one or waves it away.
    private var showsPrompt: Bool {
        entry == nil && promptsEnabled && !promptDismissed && draft.title.isEmpty && draft.body.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    if !notebook.party.isEmpty {
                        Section("Written by") {
                            AuthorPicker(members: notebook.party, selection: $draft.authorID)
                        }
                    }

                    if showsPrompt {
                        Section {
                            PromptCard(
                                context: WritingPrompts.context(
                                    for: notebook.party.first { $0.id == draft.authorID },
                                    in: notebook
                                ),
                                onUse: { prompt in
                                    draft.title = prompt
                                    focusedField = .body
                                },
                                onDismiss: { withAnimation { promptDismissed = true } }
                            )
                        }
                    }

                    Section {
                        TextField("Title", text: $draft.title)
                            .font(Theme.title(.title3))
                            .focused($focusedField, equals: .title)
                            .textInputAutocapitalization(.sentences)
                        TextField("Dear journal…", text: $draft.body, axis: .vertical)
                            .font(Theme.prose)
                            .lineLimit(8...40)
                            .focused($focusedField, equals: .body)
                    }

                    Section("How they feel") {
                        EmotionPicker(draft: $draft)
                    }

                    Section {
                        DisclosureGroup("Where and when", isExpanded: $showsDetails) {
                            DatePicker("Date", selection: $draft.writtenAt)
                            TextField("In-game date, e.g. 4th of Last Seed", text: $draft.inGameDate)
                            TextField("Place", text: $draft.place)
                                .focused($focusedField, equals: .place)
                                .textInputAutocapitalization(.words)
                            if focusedField == .place {
                                suggestionRow(Atlas.suggestions(Atlas.places(in: entries), for: draft.place)) { draft.place = $0 }
                            }
                            TextField("Quest", text: $draft.quest)
                                .focused($focusedField, equals: .quest)
                                .textInputAutocapitalization(.words)
                            if focusedField == .quest {
                                suggestionRow(Atlas.suggestions(Atlas.quests(in: entries), for: draft.quest)) { draft.quest = $0 }
                            }
                        }
                    }

                    if !notebook.party.isEmpty || !draft.bonds.isEmpty {
                        BondsSection(
                            bonds: $draft.bonds,
                            others: notebook.party.filter { $0.id != draft.authorID }
                        )
                    }

                    PhotoPickerSection(photos: $draft.photos)

                    Section {
                        Toggle(isOn: $draft.isTurningPoint.animation(.spring(duration: 0.35))) {
                            HStack(spacing: 10) {
                                WaxSeal(size: 22)
                                Text("Turning point")
                            }
                        }
                    } footer: {
                        Text("Seal the moments that changed the story: a betrayal, a victory, a farewell.")
                    }
                    .sensoryFeedback(.impact(weight: .heavy), trigger: draft.isTurningPoint) { _, sealed in sealed }
                }
                .listRowBackground(Theme.vellum)
            }
            .parchmentBackground()
            .navigationTitle(entry == nil ? "New Entry" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.isValid)
                }
            }
            .onAppear {
                if entry == nil { focusedField = .body }
            }
        }
    }

    @ViewBuilder
    private func suggestionRow(_ items: [String], pick: @escaping (String) -> Void) -> some View {
        if !items.isEmpty {
            ChipRow(items: items, selected: nil) { item in
                pick(item)
                focusedField = nil
            }
        }
    }

    private func save() {
        if let entry {
            draft.apply(to: entry, in: notebook)
        } else {
            let newEntry = draft.makeEntry(in: notebook)
            context.insert(newEntry)
            newEntry.notebook = notebook
        }
        try? context.save()
        dismiss()
    }
}

/// Avatars of the party to choose who is writing, plus an unsigned option.
struct AuthorPicker: View {
    let members: [PartyMember]
    @Binding var selection: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(members) { member in
                    option(id: member.id, label: member.name) {
                        MemberAvatar(member: member, size: 48)
                    }
                }
                option(id: nil, label: "Narrator") {
                    Image(systemName: "text.book.closed")
                        .font(.title3)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Theme.rule.opacity(0.5)))
                        .foregroundStyle(Theme.fadedInk)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func option<Avatar: View>(id: UUID?, label: String, @ViewBuilder avatar: () -> Avatar) -> some View {
        let isSelected = selection == id
        return Button {
            selection = id
        } label: {
            VStack(spacing: 4) {
                avatar()
                    .overlay(Circle().strokeBorder(Theme.ember, lineWidth: isSelected ? 3 : 0).padding(-3))
                    .opacity(isSelected ? 1 : 0.6)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Theme.ember : Theme.fadedInk)
                    .lineLimit(1)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
