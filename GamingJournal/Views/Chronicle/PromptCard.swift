import SwiftUI

/// A writing prompt shown above an empty entry. Shuffle for another, use it as the title, or
/// dismiss it for this entry.
struct PromptCard: View {
    let context: WritingPrompts.Context
    let onUse: (String) -> Void
    let onDismiss: () -> Void
    @State private var seed = Int.random(in: 0..<1_000)

    var body: some View {
        if let prompt = WritingPrompts.prompt(for: context, seed: seed) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("A prompt", systemImage: "flame")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(Theme.ember)
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(Theme.fadedInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss prompt")
                }
                Text(prompt)
                    .font(.system(.body, design: .serif))
                    .italic()
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 16) {
                    Button("Use as title") { onUse(prompt) }
                        .font(.subheadline.weight(.semibold))
                    Button {
                        seed += 1
                    } label: {
                        Label("Another", systemImage: "shuffle")
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.borderless)
                .tint(Theme.ember)
            }
            .padding(.vertical, 4)
            .sensoryFeedback(.selection, trigger: seed)
            .animation(.easeInOut(duration: 0.2), value: seed)
        }
    }
}
