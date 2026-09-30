import SwiftUI

/// Square, cropped thumbnail from stored JPEG data.
struct ThumbnailImage: View {
    let data: Data?
    let side: CGFloat

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.2)
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }
}

/// A stored photo from an entry, for the strip and viewer.
struct PhotoItem: Identifiable {
    let id: UUID
    let thumbnailData: Data?
    let imageData: Data?

    init(_ photo: EntryPhoto) {
        id = photo.id
        thumbnailData = photo.thumbnailData
        imageData = photo.imageData
    }
}

/// Horizontal strip of photos; tapping one opens the full-screen viewer.
struct PhotoStrip: View {
    let photos: [PhotoItem]
    @State private var viewerStart: UUID?

    init(photos: [PhotoItem]) {
        self.photos = photos
    }

    init(photos: [EntryPhoto]) {
        self.photos = photos.map(PhotoItem.init)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    thumbnail(photo, number: index + 1)
                }
            }
            .padding(.vertical, 4)
        }
        .fullScreenCover(item: Binding(
            get: { viewerStart.map(ViewerStart.init) },
            set: { viewerStart = $0?.id }
        )) { start in
            PhotoViewer(photos: photos, selection: start.id)
        }
    }

    private func thumbnail(_ photo: PhotoItem, number: Int) -> some View {
        let id: UUID = photo.id
        let data: Data? = photo.thumbnailData ?? photo.imageData
        return Button {
            viewerStart = id
        } label: {
            ThumbnailImage(data: data, side: 96)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Photo \(number) of \(photos.count)")
    }

    private struct ViewerStart: Identifiable {
        let id: UUID
    }
}

/// Swipeable full-screen photo viewer.
struct PhotoViewer: View {
    let photos: [PhotoItem]
    @State var selection: UUID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(photos) { photo in
                    Group {
                        if let data = photo.imageData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        } else {
                            ContentUnavailableView("Photo unavailable", systemImage: "photo")
                        }
                    }
                    .tag(photo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .background(Color.black)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
