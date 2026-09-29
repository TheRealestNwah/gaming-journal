import SwiftUI
import SwiftData

/// An entry in the chronicle: who wrote it, when, how they felt and the opening lines.
struct EntryCard: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                if let author = entry.author {
                    MemberAvatar(member: author, size: 32)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.author?.name ?? "Narrator")
                        .font(.system(.subheadline, design: .serif).weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(dateLine)
                        .font(.caption)
                        .foregroundStyle(Theme.fadedInk)
                }
                Spacer(minLength: 4)
                if entry.isTurningPoint {
                    WaxSeal(size: 26, label: "Turning point")
                }
            }
            if !entry.title.isEmpty {
                Text(entry.title)
                    .font(Theme.title(.title3))
                    .foregroundStyle(Theme.ink)
            }
            if !entry.body.isEmpty {
                Text(entry.body)
                    .font(Theme.prose)
                    .foregroundStyle(Theme.ink.opacity(0.85))
                    .lineLimit(4)
            }
            let emotions = entry.emotions.compactMap { felt in felt.emotion.map { ($0, felt.intensity) } }
            if !emotions.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(emotions, id: \.0) { emotion, intensity in
                        EmotionChip(emotion: emotion, intensity: intensity)
                    }
                }
            }
            if !entry.place.isEmpty || !entry.quest.isEmpty {
                HStack(spacing: 12) {
                    if !entry.place.isEmpty {
                        Label(entry.place, systemImage: "mappin.and.ellipse")
                    }
                    if !entry.quest.isEmpty {
                        Label(entry.quest, systemImage: "scroll")
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.fadedInk)
                .lineLimit(1)
            }
        }
        .parchmentCard()
        .accessibilityElement(children: .combine)
    }

    private var dateLine: String {
        let real = entry.writtenAt.formatted(date: .abbreviated, time: .shortened)
        return entry.inGameDate.isEmpty ? real : "\(entry.inGameDate) · \(real)"
    }
}

/// The notebook's entries with search and filters.
struct ChronicleSection: View {
    let notebook: Notebook
    @Binding var filter: ChronicleFilter
    let onWrite: () -> Void

    var body: some View {
        let all = notebook.chronicle
        let shown = filter.apply(to: all)
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onWrite) {
                Label("Write in the journal", systemImage: "pencil.and.scribble")
            }
            .buttonStyle(.ember)

            if all.isEmpty {
                Text("No entries yet. Write the first page of the tale.")
                    .font(Theme.prose)
                    .foregroundStyle(Theme.fadedInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.fadedInk)
                    TextField("Search the chronicle", text: $filter.searchText)
                        .textInputAutocapitalization(.never)
                    ChronicleFilterMenu(filter: $filter, notebook: notebook, entries: all)
                }
                .padding(10)
                .background(Theme.vellum, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.rule, lineWidth: 1))

                if shown.isEmpty {
                    VStack(spacing: 8) {
                        Text("No entries match.")
                            .font(Theme.prose)
                            .foregroundStyle(Theme.fadedInk)
                        Button("Clear filters") { filter = ChronicleFilter() }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    let chapters = notebook.orderedChapters
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(ChapterBook.parts(shown, chapters: chapters, includeEmpty: !filter.isActive)) { part in
                            if !chapters.isEmpty {
                                ChapterHeading(chapter: part.chapter)
                            }
                            if part.entries.isEmpty {
                                Text("No pages in this chapter yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.fadedInk)
                            }
                            ForEach(part.entries) { entry in
                                NavigationLink(value: entry) {
                                    EntryCard(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Title (and summary) above a chapter's entries; nil heads the entries outside every chapter.
struct ChapterHeading: View {
    let chapter: Chapter?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(chapter?.title ?? "Loose pages", systemImage: chapter == nil ? "doc.on.doc" : "bookmark.fill")
                .font(Theme.heading)
                .foregroundStyle(Theme.ember)
            if let summary = chapter?.summary, !summary.isEmpty {
                Text(summary)
                    .font(Theme.prose)
                    .foregroundStyle(Theme.fadedInk)
            }
        }
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Filter menu for the chronicle: who wrote it, what they felt, where they were.
private struct ChronicleFilterMenu: View {
    @Binding var filter: ChronicleFilter
    let notebook: Notebook
    let entries: [Entry]

    var body: some View {
        let felt = Set(entries.flatMap { $0.emotions.compactMap(\.emotion) })
        let places = Atlas.places(in: entries).map(\.name)
        Menu {
            if !notebook.party.isEmpty {
                Picker(selection: $filter.memberID) {
                    Text("Anyone").tag(UUID?.none)
                    ForEach(notebook.party) { member in
                        Text(member.name).tag(UUID?.some(member.id))
                    }
                } label: {
                    Label("Written by", systemImage: "person")
                }
                .pickerStyle(.menu)
            }
            if !felt.isEmpty {
                Picker(selection: $filter.emotion) {
                    Text("Any feeling").tag(Emotion?.none)
                    ForEach(Emotion.allCases.filter(felt.contains)) { emotion in
                        Label(emotion.label, systemImage: emotion.systemImage).tag(Emotion?.some(emotion))
                    }
                } label: {
                    Label("Feeling", systemImage: "heart")
                }
                .pickerStyle(.menu)
            }
            if !notebook.orderedChapters.isEmpty {
                Picker(selection: $filter.chapterID) {
                    Text("Any chapter").tag(UUID?.none)
                    ForEach(notebook.orderedChapters) { chapter in
                        Text(chapter.title).tag(UUID?.some(chapter.id))
                    }
                } label: {
                    Label("Chapter", systemImage: "bookmark")
                }
                .pickerStyle(.menu)
            }
            if !places.isEmpty {
                Picker(selection: $filter.place) {
                    Text("Anywhere").tag(String?.none)
                    ForEach(places, id: \.self) { place in
                        Text(place).tag(String?.some(place))
                    }
                } label: {
                    Label("Place", systemImage: "mappin")
                }
                .pickerStyle(.menu)
            }
            Toggle("Turning points only", systemImage: "seal", isOn: $filter.turningPointsOnly)
            if filter.hasFacets {
                Divider()
                Button("Clear filters", systemImage: "xmark", role: .destructive) { filter.clearFacets() }
            }
        } label: {
            Image(systemName: filter.hasFacets
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
                .foregroundStyle(Theme.ember)
                .accessibilityLabel("Filter")
        }
    }
}

/// Places and quests the party has written about.
struct AtlasSection: View {
    let notebook: Notebook
    let onSelectPlace: (String) -> Void

    var body: some View {
        let entries = notebook.entries ?? []
        let places = Atlas.places(in: entries)
        let quests = Atlas.quests(in: entries)
        VStack(alignment: .leading, spacing: 16) {
            if places.isEmpty && quests.isEmpty {
                Text("Add a place or quest to an entry and it appears here, like a map filling in.")
                    .font(Theme.prose)
                    .foregroundStyle(Theme.fadedInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
            if !places.isEmpty {
                atlasList("Places", systemImage: "mappin.and.ellipse", items: places, onSelect: onSelectPlace)
            }
            if !quests.isEmpty {
                atlasList("Quests", systemImage: "scroll", items: quests, onSelect: nil)
            }
        }
    }

    private func atlasList(
        _ title: LocalizedStringKey,
        systemImage: String,
        items: [Atlas.Item],
        onSelect: ((String) -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(Theme.heading)
                .foregroundStyle(Theme.ember)
            VStack(spacing: 0) {
                ForEach(items) { item in
                    Button {
                        onSelect?(item.name)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(.body, design: .serif))
                                    .foregroundStyle(Theme.ink)
                                Text(item.writers.isEmpty ? "\(item.entryCount) entries" : "\(item.entryCount) entries · \(item.writers.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(Theme.fadedInk)
                            }
                            Spacer()
                            Text(item.lastSeen, format: .relative(presentation: .named))
                                .font(.caption)
                                .foregroundStyle(Theme.fadedInk)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(onSelect == nil)
                    if item.id != items.last?.id {
                        Divider().overlay(Theme.rule)
                    }
                }
            }
            .parchmentCard(padding: 12)
        }
    }
}

/// A single entry, laid out like a journal page.
struct EntryDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(UndoCenter.self) private var undoCenter
    let entry: Entry
    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var isSharing = false

    var body: some View {
        if entry.isDeleted || entry.modelContext == nil {
            ContentUnavailableView("Entry deleted", systemImage: "trash")
        } else {
            page
        }
    }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    if let author = entry.author {
                        MemberAvatar(member: author, size: 44)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.author?.name ?? "Narrator")
                            .font(Theme.heading)
                        if let role = entry.author?.role, !role.isEmpty {
                            Text(role)
                                .font(.caption)
                                .foregroundStyle(Theme.fadedInk)
                        }
                    }
                    Spacer()
                    if entry.isTurningPoint {
                        WaxSeal(size: 36, label: "Turning point")
                    }
                }

                if !entry.title.isEmpty {
                    Text(entry.title)
                        .font(Theme.title(.title))
                }

                VStack(alignment: .leading, spacing: 4) {
                    if !entry.inGameDate.isEmpty {
                        Label(entry.inGameDate, systemImage: "moon.stars")
                    }
                    if let chapter = entry.chapter {
                        Label(chapter.title, systemImage: "bookmark")
                    }
                    Label(entry.writtenAt.formatted(date: .complete, time: .shortened), systemImage: "calendar")
                    if !entry.place.isEmpty {
                        Label(entry.place, systemImage: "mappin.and.ellipse")
                    }
                    if !entry.quest.isEmpty {
                        Label(entry.quest, systemImage: "scroll")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Theme.fadedInk)

                let emotions = entry.emotions.compactMap { felt in felt.emotion.map { ($0, felt.intensity) } }
                if !emotions.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(emotions, id: \.0) { emotion, intensity in
                            EmotionChip(emotion: emotion, intensity: intensity)
                        }
                    }
                }

                SectionFlourish()

                if !entry.body.isEmpty {
                    Text(entry.body)
                        .font(Theme.prose)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }

                if !entry.sortedPhotos.isEmpty {
                    PhotoStrip(photos: entry.sortedPhotos)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .parchmentCard(padding: 0)
            .padding()
        }
        .background(ParchmentBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Share as Image", systemImage: "square.and.arrow.up") { isSharing = true }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Delete Entry", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            if let notebook = entry.notebook {
                EntryEditorView(notebook: notebook, entry: entry)
            }
        }
        .sheet(isPresented: $isSharing) {
            ShareEntrySheet(entry: entry)
        }
        .confirmationDialog("Delete this entry?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                dismiss()
                context.deleteEntry(entry, undo: undoCenter)
            }
        } message: {
            Text("You can undo for a few seconds.")
        }
    }
}
