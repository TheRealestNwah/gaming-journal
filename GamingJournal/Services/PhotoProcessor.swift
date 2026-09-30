import UIKit

/// Shrinks picked images before they're stored: a full-size JPEG capped at `maxDimension` and a
/// small thumbnail for strips.
enum PhotoProcessor {
    static let maxDimension: CGFloat = 2048
    static let thumbnailDimension: CGFloat = 320

    struct Processed: Equatable, Sendable {
        var imageData: Data
        var thumbnailData: Data
    }

    /// Scales `size` down so its longer side is at most `maxDimension`, keeping the aspect ratio.
    /// Never scales up. Sides are rounded to whole pixels and kept at least 1.
    static func fittedSize(for size: CGSize, maxDimension: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0, maxDimension > 0 else { return .zero }
        let scale = min(1, maxDimension / max(size.width, size.height))
        return CGSize(
            width: max(1, (size.width * scale).rounded()),
            height: max(1, (size.height * scale).rounded())
        )
    }

    static func process(_ data: Data) -> Processed? {
        UIImage(data: data).flatMap { process($0) }
    }

    /// A photo straight from the camera.
    static func process(_ image: UIImage) -> Processed? {
        guard let full = jpeg(image, maxDimension: maxDimension, quality: 0.85),
              let thumbnail = jpeg(image, maxDimension: thumbnailDimension, quality: 0.7)
        else { return nil }
        return Processed(imageData: full, thumbnailData: thumbnail)
    }

    static func jpeg(_ image: UIImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let target = fittedSize(for: image.size, maxDimension: maxDimension)
        guard target != .zero else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: quality)
    }
}
