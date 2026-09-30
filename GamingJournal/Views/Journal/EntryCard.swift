import SwiftUI
import UIKit

/// One entry as a picture of its page, for sharing: the date, the place, the words and the first
/// picture on aged paper, signed with whose journal it's from.
struct EntryCard: View {
    let heading: String
    let place: String
    let text: String
    let picture: UIImage?
    let journalTitle: String

    /// The card's width in points; rendered at 3× for a sharp 1080-pixel image.
    static let width: CGFloat = 360

    init(entry: Entry, journal: Journal) {
        heading = entry.heading()
        place = entry.place
        text = entry.body
        picture = entry.sortedPhotos.first.flatMap { $0.imageData ?? $0.thumbnailData }.flatMap(UIImage.init(data:))
        journalTitle = journal.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(heading)
                .font(Theme.dateLine)
                .foregroundStyle(Theme.rubric)
            if !place.isEmpty {
                Text(place)
                    .font(Theme.bookItalic(16))
                    .foregroundStyle(Theme.fadedInk)
            }
            PageRule()
            if !text.isEmpty {
                Text(text)
                    .font(Theme.book(17))
                    .lineSpacing(3)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(18)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let picture {
                Image(uiImage: picture)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Text("— from \(journalTitle)")
                .font(Theme.bookItalic(14))
                .foregroundStyle(Theme.fadedInk)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 4)
        }
        .padding(28)
        .frame(width: Self.width, alignment: .leading)
        .background(PaperBackground())
        // The same page whatever the phone's settings.
        .environment(\.colorScheme, .light)
        .dynamicTypeSize(.large)
    }

    /// The card as an image, or nil if it couldn't be drawn.
    @MainActor
    func render() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// The system share sheet for an image.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
