import SwiftUI
import SwiftData
import PhotosUI

/// A blank page to write on: the in-game date, the words, and optionally a picture or two.
struct WriterView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let journal: Journal
    private let entry: Entry?
    @State private var draft: EntryDraft
    /// An unfinished new entry left in this journal, offered back until the writer decides.
    @State private var unfinished: DraftShelf.Saved?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @FocusState private var bodyFocused: Bool
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 19
    private let drafts = DraftShelf()

    init(journal: Journal, entry: Entry? = nil) {
        self.journal = journal
        self.entry = entry
        _draft = State(initialValue: entry.map(EntryDraft.init(entry:)) ?? EntryDraft.new(in: journal))
        _unfinished = State(initialValue: entry == nil ? DraftShelf().saved(for: journal.id) : nil)
    }

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 0) {
                topBar
                PageRule()
                    .padding(.bottom, 12)

                if let unfinished {
                    unfinishedOffer(unfinished)
                }

                TextField("In-game date", text: $draft.inGameDate, prompt: Text("In-game date, e.g. 17th of Last Seed").foregroundStyle(Theme.fadedInk.opacity(0.7)))
                    .font(Theme.dateLine)
                    .foregroundStyle(Theme.rubric)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("inGameDate")
                    .submitLabel(.next)
                    .onSubmit { bodyFocused = true }
                dateHints
                    .padding(.top, 4)

                ZStack(alignment: .topLeading) {
                    if draft.body.isEmpty {
                        Text("Dear journal…")
                            .font(Theme.bookItalic(fontSize))
                            .foregroundStyle(Theme.fadedInk.opacity(0.7))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .accessibilityHidden(true)
                    }
                    TextEditor(text: $draft.body)
                        .font(Theme.book(fontSize))
                        .lineSpacing(fontSize * 0.22)
                        .foregroundStyle(Theme.ink)
                        .scrollContentBackground(.hidden)
                        .focused($bodyFocused)
                        .accessibilityLabel("Entry")
                        .accessibilityIdentifier("entryBody")
                }
                .padding(.top, 8)

                if !draft.photos.isEmpty {
                    photoStrip
                }
                tools
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .tint(Theme.rubric)
        .onAppear {
            if entry == nil && unfinished == nil { bodyFocused = true }
        }
        // Keep new writing safe from an accidental dismissal or the app being closed, but not over
        // an unfinished page still waiting to be carried on or discarded.
        .onChange(of: draft) { _, draft in
            if entry == nil && unfinished == nil { drafts.keep(draft, for: journal.id) }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await load(items) }
        }
    }

    // MARK: Parts

    private var topBar: some View {
        HStack {
            Button("Cancel") {
                if entry == nil && unfinished == nil { drafts.discard(for: journal.id) }
                dismiss()
            }
            Spacer()
            Text(entry == nil ? "A new page" : "Amend the page")
                .font(Theme.bookItalic(16, relativeTo: .headline))
                .foregroundStyle(Theme.fadedInk)
            Spacer()
            Button("Done", action: save)
                .fontWeight(.semibold)
                .disabled(!draft.isValid)
        }
        .font(Theme.pageControl)
        .foregroundStyle(Theme.rubric)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    /// "Next day" for dates it can read, and when the entry is filed in the real world.
    private var dateHints: some View {
        HStack(spacing: 14) {
            if let next = InGameDate.nextDay(after: draft.inGameDate) {
                Button {
                    draft.inGameDate = next
                } label: {
                    Label("Next day", systemImage: "arrow.forward")
                }
                .accessibilityHint("Sets the date to \(next)")
            }
            Text("written \(draft.writtenAt.formatted(date: .abbreviated, time: .omitted))")
                .foregroundStyle(Theme.fadedInk)
        }
        .font(Theme.bookItalic(15, relativeTo: .footnote))
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(draft.photos) { photo in
                    ThumbnailImage(data: photo.thumbnailData, side: 64)
                        .overlay(alignment: .topTrailing) {
                            Button {
                                draft.photos.removeAll { $0.id == photo.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .padding(3)
                            .accessibilityLabel("Remove picture")
                        }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var tools: some View {
        HStack(alignment: .top, spacing: 22) {
            DictationRow(text: $draft.body)
            PhotosPicker(selection: $pickerItems, maxSelectionCount: 6, matching: .images) {
                Label(isLoadingPhotos ? "Adding…" : "Picture", systemImage: "photo")
                    .font(Theme.pageControl)
            }
            .disabled(isLoadingPhotos)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.rubric)
        .padding(.vertical, 10)
    }

    private func unfinishedOffer(_ saved: DraftShelf.Saved) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("An unfinished page was left here \(saved.savedAt.formatted(.relative(presentation: .named))).")
                .font(Theme.bookItalic(16))
                .foregroundStyle(Theme.fadedInk)
            if !saved.preview.isEmpty {
                Text("“\(saved.preview)”")
                    .font(Theme.book(16))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
            }
            HStack(spacing: 20) {
                Button("Carry on writing") {
                    draft = saved.draft
                    unfinished = nil
                    bodyFocused = true
                }
                .fontWeight(.semibold)
                Button("Discard it", role: .destructive) {
                    unfinished = nil
                    // Whatever was written meanwhile becomes the page kept safe.
                    drafts.keep(draft, for: journal.id)
                    bodyFocused = true
                }
            }
            .font(Theme.pageControl)
            .foregroundStyle(Theme.rubric)
        }
        .padding(.bottom, 14)
    }

    // MARK: Actions

    private func save() {
        if let entry {
            draft.apply(to: entry, in: journal)
        } else {
            let entry = Entry()
            context.insert(entry)
            draft.apply(to: entry, in: journal)
            drafts.discard(for: journal.id)
        }
        try? context.save()
        dismiss()
    }

    private func load(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        defer {
            isLoadingPhotos = false
            pickerItems = []
        }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let processed = await Task.detached(operation: { PhotoProcessor.process(data) }).value
            else { continue }
            draft.photos.append(DraftPhoto(imageData: processed.imageData, thumbnailData: processed.thumbnailData))
        }
    }
}
