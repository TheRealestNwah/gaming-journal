import SwiftUI
import SwiftData

/// Compact bar shown while a timer is running or paused.
struct TimerBanner: View {
    @Environment(LiveTimer.self) private var timer
    let onStop: (SessionDraft) -> Void

    var body: some View {
        if let state = timer.state {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.gameTitle.isEmpty ? "Playing" : state.gameTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(PlaytimeFormatter.clock(fromSeconds: state.elapsed(at: context.date)))
                            .font(.title3.monospacedDigit().weight(.medium))
                            .foregroundStyle(state.isPaused ? .secondary : .primary)
                    }
                }
                Spacer(minLength: 8)
                Button {
                    state.isPaused ? timer.resume() : timer.pause()
                } label: {
                    Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel(state.isPaused ? "Resume timer" : "Pause timer")

                Button {
                    if let draft = timer.stop() { onStop(draft) }
                } label: {
                    Image(systemName: "stop.fill")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Stop and log session")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            .padding(.horizontal)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(state.isPaused ? "Timer paused" : "Timer running")
            .sensoryFeedback(.impact(weight: .light), trigger: state.isPaused)
        }
    }
}

/// Asks for an optional game title, then starts the timer.
struct StartTimerSheet: View {
    @Environment(LiveTimer.self) private var timer
    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [PlaySession]
    @State private var title = ""
    @FocusState private var focused: Bool

    private var index: GameTitleIndex {
        GameTitleIndex(sessions: sessions)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Game title (optional)", text: $title)
                        .focused($focused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit(start)
                    let suggestions = index.suggestions(for: title)
                    if !suggestions.isEmpty {
                        ChipRow(items: suggestions, selected: nil) { title = $0 }
                    }
                } footer: {
                    Text("The timer keeps running if you leave the app. Stop it to log the session.")
                }
            }
            .navigationTitle("Start Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", action: start)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }

    private func start() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        timer.start(gameTitle: trimmed.isEmpty ? "" : index.canonicalTitle(for: trimmed))
        dismiss()
    }
}
