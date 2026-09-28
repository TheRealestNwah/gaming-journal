import SwiftUI
import PhotosUI

/// Editor section: pick photos, see thumbnails, remove them.
struct PhotoPickerSection: View {
    @Binding var photos: [DraftPhoto]
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoading = false

    var body: some View {
        Section("Photos") {
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos) { photo in
                            ThumbnailImage(data: photo.thumbnailData, side: 72)
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        photos.removeAll { $0.id == photo.id }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .black.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(3)
                                    .accessibilityLabel("Remove photo")
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                HStack {
                    Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                    if isLoading {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isLoading)
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await load(items) }
        }
    }

    private func load(_ items: [PhotosPickerItem]) async {
        isLoading = true
        defer {
            isLoading = false
            pickerItems = []
        }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let processed = await Task.detached(operation: { PhotoProcessor.process(data) }).value
            else { continue }
            photos.append(DraftPhoto(imageData: processed.imageData, thumbnailData: processed.thumbnailData))
        }
    }
}

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

/// Horizontal strip of a session's photos; tapping one opens the full-screen viewer.
struct PhotoStrip: View {
    let photos: [SessionPhoto]
    @State private var viewerStart: SessionPhoto.ID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(photos) { photo in
                    Button {
                        viewerStart = photo.id
                    } label: {
                        ThumbnailImage(data: photo.thumbnailData ?? photo.imageData, side: 96)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Photo \((photos.firstIndex(of: photo) ?? 0) + 1) of \(photos.count)")
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

    private struct ViewerStart: Identifiable {
        let id: UUID
    }
}

/// Swipeable full-screen photo viewer.
struct PhotoViewer: View {
    let photos: [SessionPhoto]
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
