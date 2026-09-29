import SwiftUI
import SwiftData

/// Add, rename, reorder and remove a notebook's chapters. Removing a chapter keeps its entries.
struct ChaptersEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let notebook: Notebook
    @State private var newTitle = ""
    @FocusState private var isAdding: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Act II: The Underdark", text: $newTitle)
                            .focused($isAdding)
                            .textInputAutocapitalization(.words)
                            .onSubmit(add)
                        Button("Add", systemImage: "plus.circle.fill", action: add)
                            .labelStyle(.iconOnly)
                            .foregroundStyle(Theme.ember)
                            .disabled(ChapterBook.tidyTitle(newTitle).isEmpty)
                    }
                } header: {
                    Text("New chapter")
                } footer: {
                    Text("New entries start in the last chapter.")
                }
                .listRowBackground(Theme.vellum)

                if !notebook.orderedChapters.isEmpty {
                    Section {
                        ForEach(notebook.orderedChapters) { chapter in
                            ChapterRow(chapter: chapter)
                        }
                        .onMove { source, destination in
                            ChapterBook.move(notebook.orderedChapters, from: source, to: destination)
                            notebook.touch()
                        }
                        .onDelete { offsets in
                            let chapters = notebook.orderedChapters
                            for index in offsets {
                                context.delete(chapters[index])
                            }
                            notebook.touch()
                        }
                    } header: {
                        Text("Chapters")
                    } footer: {
                        Text("Removing a chapter keeps its entries; they become loose pages.")
                    }
                    .listRowBackground(Theme.vellum)
                }
            }
            .scrollContentBackground(.hidden)
            .parchmentBackground()
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .onAppear {
                if notebook.orderedChapters.isEmpty { isAdding = true }
            }
            // Covers Done and swipe-to-dismiss alike.
            .onDisappear {
                ChapterBook.tidyTitles(of: notebook.orderedChapters)
                try? context.save()
            }
        }
    }

    private func add() {
        let title = ChapterBook.tidyTitle(newTitle)
        guard !title.isEmpty else { return }
        let chapter = Chapter(title: title, sortIndex: ChapterBook.nextSortIndex(in: notebook))
        context.insert(chapter)
        chapter.notebook = notebook
        notebook.touch()
        newTitle = ""
    }
}

/// A chapter's title and summary, edited in place.
private struct ChapterRow: View {
    @Bindable var chapter: Chapter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Title", text: $chapter.title)
                .font(.system(.body, design: .serif).weight(.semibold))
                .textInputAutocapitalization(.words)
            TextField("What happens in this chapter (optional)", text: $chapter.summary, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(Theme.fadedInk)
                .lineLimit(1...4)
            Text("^[\(chapter.entries?.count ?? 0) entry](inflect: true)")
                .font(.caption)
                .foregroundStyle(Theme.fadedInk)
        }
        .padding(.vertical, 2)
    }
}
