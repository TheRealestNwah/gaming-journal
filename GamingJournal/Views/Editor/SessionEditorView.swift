import SwiftUI
import SwiftData

/// Add or edit a play session. Pass `session` to edit; leave it nil to create one.
struct SessionEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allSessions: [PlaySession]

    private let session: PlaySession?
    private let onSave: (() -> Void)?
    @State private var draft: SessionDraft
    @State private var platformTouched = false
    @FocusState private var titleFocused: Bool

    init(session: PlaySession? = nil, prefill: SessionDraft? = nil, onSave: (() -> Void)? = nil) {
        self.session = session
        self.onSave = onSave
        _draft = State(initialValue: session.map(SessionDraft.init(session:)) ?? prefill ?? SessionDraft())
    }

    private var index: GameTitleIndex {
        GameTitleIndex(sessions: allSessions)
    }

    private var platformOptions: [String] {
        PlatformPresets.options(including: allSessions.map(\.platform))
    }

    var body: some View {
        NavigationStack {
            Form {
                gameSection
                timeSection
                feelSection
                notesSection
                milestoneSection
            }
            .navigationTitle(session == nil ? "New Session" : "Edit Session")
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
                if session == nil && draft.gameTitle.isEmpty { titleFocused = true }
            }
        }
    }

    // MARK: Sections

    private var gameSection: some View {
        Section("Game") {
            TextField("Game title", text: $draft.gameTitle)
                .focused($titleFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .onChange(of: draft.gameTitle) { _, newTitle in
                    fillPlatform(for: newTitle)
                }
            let suggestions = index.suggestions(for: draft.gameTitle)
            if titleFocused && !suggestions.isEmpty {
                ChipRow(items: suggestions, selected: nil) { title in
                    draft.gameTitle = title
                    titleFocused = false
                }
            }
            TextField("Platform", text: Binding(
                get: { draft.platform },
                set: { draft.platform = $0; platformTouched = true }
            ))
            .autocorrectionDisabled()
            ChipRow(items: platformOptions, selected: draft.platform) { platform in
                draft.platform = platform
                platformTouched = true
            }
        }
    }

    private var timeSection: some View {
        Section("When") {
            DatePicker("Started", selection: $draft.startDate)
            Stepper(value: $draft.durationMinutes, in: 0...(24 * 60), step: 5) {
                LabeledContent("Played", value: PlaytimeFormatter.string(fromMinutes: draft.durationMinutes))
            }
            ChipRow(
                items: DurationPresets.quickMinutes.map { PlaytimeFormatter.string(fromMinutes: $0) },
                selected: PlaytimeFormatter.string(fromMinutes: draft.durationMinutes)
            ) { label in
                if let minutes = DurationPresets.quickMinutes.first(where: {
                    PlaytimeFormatter.string(fromMinutes: $0) == label
                }) {
                    draft.durationMinutes = minutes
                }
            }
        }
    }

    private var feelSection: some View {
        Section("How it felt") {
            LabeledContent("Enjoyment") {
                StarRatingControl(rating: $draft.enjoyment)
            }
            Picker("Mood", selection: $draft.mood) {
                Text("None").tag(Mood?.none)
                ForEach(Mood.allCases) { mood in
                    Text("\(mood.emoji) \(mood.label)").tag(Mood?.some(mood))
                }
            }
        }
    }

    private var notesSection: some View {
        Section {
            TextField("What happened?", text: $draft.notes, axis: .vertical)
                .lineLimit(4...12)
            TextField("Tags (comma separated)", text: $draft.tagsText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Notes")
        } footer: {
            if !draft.tags.isEmpty {
                Text(draft.tags.map { "#\($0)" }.joined(separator: " "))
            }
        }
    }

    private var milestoneSection: some View {
        Section {
            Toggle("Milestone", isOn: $draft.isMilestone.animation())
            if draft.isMilestone {
                TextField("e.g. Beat the final boss", text: $draft.milestoneNote)
            }
        } footer: {
            Text("Mark sessions worth remembering: finishing a game, a big boss, a rare drop.")
        }
    }

    // MARK: Actions

    /// Fills the platform from the last session of this game until the user picks one themselves.
    private func fillPlatform(for title: String) {
        guard !platformTouched, let last = index.lastPlatform(for: title) else { return }
        draft.platform = last
    }

    private func save() {
        if let session {
            draft.apply(to: session, index: index)
        } else {
            context.insert(draft.makeSession(index: index))
        }
        onSave?()
        dismiss()
    }
}

/// Horizontally scrolling row of tappable capsules.
struct ChipRow: View {
    let items: [String]
    let selected: String?
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    let isSelected = item.caseInsensitiveCompare(selected ?? "") == .orderedSame
                    Button(item) { onTap(item) }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(isSelected ? .accentColor : .secondary)
                        .controlSize(.small)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

/// 1–5 stars; tapping the current rating clears it.
struct StarRatingControl: View {
    @Binding var rating: Int?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    rating = rating == value ? nil : value
                } label: {
                    Image(systemName: value <= (rating ?? 0) ? "star.fill" : "star")
                        .foregroundStyle(value <= (rating ?? 0) ? Color.yellow : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(value) star\(value == 1 ? "" : "s")")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue(rating.map { "\($0) of 5" } ?? "Not rated")
    }
}

#Preview {
    SessionEditorView()
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
}
