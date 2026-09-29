import SwiftUI

/// Choose a card shape and whether to include the text, preview it, then share the image.
struct ShareEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: Entry
    @State private var format = ShareCard.Format.square
    @State private var includesText = true

    var body: some View {
        let content = ShareCard.content(for: entry, format: format, includesText: includesText)
        NavigationStack {
            Form {
                Section {
                    EntryCardImage(content: content, format: format)
                        .aspectRatio(format.pixelSize.width / format.pixelSize.height, contentMode: .fit)
                        .frame(maxHeight: 420)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                        .listRowBackground(Color.clear)
                        .accessibilityLabel("Preview of the card")
                }
                Section {
                    Picker("Shape", selection: $format) {
                        ForEach(ShareCard.Format.allCases) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Include what was written", isOn: $includesText)
                } footer: {
                    Text("Turn the text off to share just the moment: who, when, where and how they felt.")
                }
                .listRowBackground(Theme.vellum)
            }
            .parchmentBackground()
            .navigationTitle("Share Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let image = render(content) {
                        ShareLink(
                            item: image,
                            preview: SharePreview(ShareCard.filename(for: entry), image: image)
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func render(_ content: ShareCard.Content) -> Image? {
        let size = format.pixelSize
        let renderer = ImageRenderer(
            content: EntryCardImage(content: content, format: format)
                .frame(width: size.width / 3, height: size.height / 3)
                // Cards always print on light parchment, whatever the phone's appearance.
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// The card itself: parchment, the writer's sigil, the entry's moment and (optionally) its words.
/// Drawn at a third of the pixel size and rendered at 3×.
struct EntryCardImage: View {
    let content: ShareCard.Content
    let format: ShareCard.Format

    var body: some View {
        ZStack {
            ParchmentBackground()
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Theme.gold.opacity(0.7), lineWidth: 1.5)
                .padding(10)
            VStack(alignment: .leading, spacing: format == .story ? 14 : 9) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(content.writer)
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                        if !content.role.isEmpty {
                            Text(content.role)
                                .font(.system(size: 9, design: .serif))
                                .foregroundStyle(Theme.fadedInk)
                        }
                    }
                    Spacer(minLength: 4)
                    if content.isTurningPoint {
                        WaxSeal(size: 24)
                    }
                }
                if !content.title.isEmpty {
                    Text(content.title)
                        .font(.system(size: format == .story ? 26 : 21, weight: .bold, design: .serif))
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                }
                Text([content.dateLine, content.place].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 9, design: .serif))
                    .foregroundStyle(Theme.fadedInk)
                if !content.emotions.isEmpty {
                    Text(content.emotions.map(\.label).joined(separator: " · "))
                        .font(.system(size: 10, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.ember)
                }
                if let excerpt = content.excerpt {
                    Rectangle()
                        .fill(Theme.rule)
                        .frame(height: 1)
                    Text(excerpt)
                        .font(.system(size: format == .story ? 13 : 11, design: .serif))
                        .lineSpacing(3)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
                if !content.notebookTitle.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed.fill")
                        Text(content.notebookTitle)
                    }
                    .font(.system(size: 9, design: .serif))
                    .foregroundStyle(Theme.fadedInk)
                }
            }
            .foregroundStyle(Theme.ink)
            .padding(24)
        }
    }
}
