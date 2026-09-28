import SwiftUI
import SwiftData

/// Create or edit a notebook. Pass `notebook` to edit; leave it nil to begin a new one.
struct NotebookEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [PlaySession]
    @Query private var notebooks: [Notebook]

    private let notebook: Notebook?
    @State private var draft: NotebookDraft
    @FocusState private var titleFocused: Bool

    init(notebook: Notebook? = nil) {
        self.notebook = notebook
        _draft = State(initialValue: notebook.map(NotebookDraft.init(notebook:)) ?? NotebookDraft())
    }

    private var gameSuggestions: [String] {
        let entries = sessions.map { GameTitleIndex.Entry(title: $0.gameTitle, platform: $0.platform, date: $0.startDate) }
            + notebooks.map { GameTitleIndex.Entry(title: $0.gameTitle, platform: $0.platform, date: $0.updatedAt) }
        return GameTitleIndex(entries: entries).suggestions(for: draft.gameTitle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        TextField("Title, e.g. The Dragonborn's Road", text: $draft.title)
                            .font(Theme.heading)
                            .focused($titleFocused)
                            .textInputAutocapitalization(.words)
                        TextField("Game", text: $draft.gameTitle)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                        if !gameSuggestions.isEmpty && !draft.gameTitle.isEmpty {
                            ChipRow(items: gameSuggestions, selected: nil) { draft.gameTitle = $0 }
                        }
                        TextField("Platform", text: $draft.platform)
                            .autocorrectionDisabled()
                        ChipRow(items: PlatformPresets.all, selected: draft.platform) { draft.platform = $0 }
                    } header: {
                        Text("The tale")
                    } footer: {
                        Text("Leave the title blank to name it after the game.")
                    }

                    Section("Cover") {
                        CoverPicker(selection: $draft.coverStyle, title: draft.resolvedTitle)
                    }

                    Section {
                        DatePicker("Began", selection: $draft.startedAt, displayedComponents: .date)
                        if notebook != nil {
                            Picker("Status", selection: $draft.status) {
                                ForEach(NotebookStatus.allCases) { status in
                                    Label(status.label, systemImage: status.systemImage).tag(status)
                                }
                            }
                        }
                        TextField("What is this playthrough about?", text: $draft.summary, axis: .vertical)
                            .font(Theme.prose)
                            .lineLimit(3...8)
                    } header: {
                        Text("Details")
                    }
                }
                .listRowBackground(Theme.vellum)
            }
            .parchmentBackground()
            .navigationTitle(notebook == nil ? "New Notebook" : "Edit Notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(notebook == nil ? "Create" : "Save", action: save)
                        .disabled(!draft.isValid)
                }
            }
            .onAppear {
                if notebook == nil { titleFocused = true }
            }
        }
    }

    private func save() {
        if let notebook {
            draft.apply(to: notebook)
        } else {
            context.insert(draft.makeNotebook())
        }
        try? context.save()
        dismiss()
    }
}

/// Horizontal row of miniature covers to pick from.
private struct CoverPicker: View {
    @Binding var selection: CoverStyle
    let title: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(CoverStyle.allCases) { style in
                    Button {
                        selection = style
                    } label: {
                        VStack(spacing: 6) {
                            LeatherCover(title: title.isEmpty ? style.label : title, style: style)
                                .frame(width: 76)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Theme.ember, lineWidth: selection == style ? 3 : 0)
                                )
                            Text(style.label)
                                .font(.caption)
                                .foregroundStyle(selection == style ? Theme.ember : Theme.fadedInk)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(style.label) cover")
                    .accessibilityAddTraits(selection == style ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

#Preview {
    NotebookEditorView()
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
}
