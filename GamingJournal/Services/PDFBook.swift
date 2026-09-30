import SwiftUI
import UIKit

/// A journal typeset as a small printed book: a leather cover page, then every entry on aged
/// pages under its date, set in the same book face as the app.
enum PDFBook {
    /// A 6 × 9 inch trade paperback page.
    static let pageSize = CGSize(width: 432, height: 648)
    static let margin: CGFloat = 50

    private static let paper = UIColor(red: 0.94, green: 0.89, blue: 0.78, alpha: 1)
    private static let ink = UIColor(red: 0.18, green: 0.13, blue: 0.09, alpha: 1)
    private static let fadedInk = UIColor(red: 0.37, green: 0.27, blue: 0.19, alpha: 1)
    private static let rubric = UIColor(red: 0.48, green: 0.18, blue: 0.11, alpha: 1)
    private static let gold = UIColor(red: 0.84, green: 0.71, blue: 0.42, alpha: 1)
    private static let cream = UIColor(red: 0.95, green: 0.90, blue: 0.80, alpha: 1)

    static func render(_ journal: Journal, locale: Locale = .current) -> Data {
        let bounds = CGRect(origin: .zero, size: pageSize)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: journal.title,
            kCGPDFContextCreator as String: "Hearthbound",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        return renderer.pdfData { context in
            var pageNumber = 0
            func newPage(numbered: Bool = true) {
                context.beginPage()
                pageNumber += 1
                paper.setFill()
                context.fill(bounds)
                if numbered {
                    draw("\(pageNumber - 1)", font: book(10), color: fadedInk, centeredAt: CGPoint(x: bounds.midX, y: bounds.maxY - 30))
                }
            }

            newPage(numbered: false)
            drawCover(journal, in: bounds)

            let entries = journal.story
            if !entries.isEmpty {
                newPage()
                flow(pages(entries, locale: locale), in: context, newPage: { newPage() })
            }
        }
    }

    static func filename(for journal: Journal) -> String {
        JournalMarkdown.filename(for: journal)
    }

    // MARK: Pages

    private static func drawCover(_ journal: Journal, in bounds: CGRect) {
        let leather = UIColor(journal.coverStyle.colors.last ?? .brown)
        let band = bounds.insetBy(dx: 36, dy: 60)
        leather.setFill()
        UIBezierPath(roundedRect: band, cornerRadius: 12).fill()
        gold.setStroke()
        let tooled = UIBezierPath(roundedRect: band.insetBy(dx: 12, dy: 12), cornerRadius: 8)
        tooled.lineWidth = 1.5
        tooled.stroke()

        let text = band.insetBy(dx: 32, dy: 0)
        var y = drawCentered("The Journal of", font: book(15, italic: true), color: cream.withAlphaComponent(0.85), top: band.minY + 150, in: text)
        y = drawCentered(journal.characterName, font: book(30, weight: .semibold), color: cream, top: y + 8, in: text)
        if !journal.subtitle.isEmpty {
            _ = drawCentered(journal.subtitle, font: book(13, italic: true), color: cream.withAlphaComponent(0.8), top: y + 14, in: text)
        }
    }

    /// The text box on every page.
    static var textBox: CGRect {
        CGRect(origin: .zero, size: pageSize).insetBy(dx: margin, dy: margin)
    }

    /// The tallest a picture may be, so it always fits on a page with room for words around it.
    static var maxPictureHeight: CGFloat {
        (textBox.height * 0.45).rounded()
    }

    /// Every entry as one flowing run of text: a date heading, the words, then its pictures.
    static func pages(_ entries: [Entry], locale: Locale) -> NSAttributedString {
        let text = NSMutableAttributedString()
        let heading = NSMutableParagraphStyle()
        heading.paragraphSpacingBefore = 16
        heading.paragraphSpacing = 4
        let body = NSMutableParagraphStyle()
        body.lineSpacing = 3.5
        body.paragraphSpacing = 6
        body.alignment = .justified
        body.hyphenationFactor = 0.8
        let place = NSMutableParagraphStyle()
        place.paragraphSpacing = 4
        let picture = NSMutableParagraphStyle()
        picture.alignment = .center
        picture.paragraphSpacingBefore = 6
        picture.paragraphSpacing = 6

        for entry in entries {
            text.append(NSAttributedString(
                string: entry.heading(locale: locale) + "\n",
                attributes: [.font: book(13, weight: .semibold), .foregroundColor: rubric, .paragraphStyle: heading]
            ))
            if !entry.place.isEmpty {
                text.append(NSAttributedString(
                    string: entry.place + "\n",
                    attributes: [.font: book(11.5, italic: true), .foregroundColor: fadedInk, .paragraphStyle: place]
                ))
            }
            if !entry.body.isEmpty {
                text.append(NSAttributedString(string: entry.body + "\n", attributes: [.font: book(12.5), .foregroundColor: ink, .paragraphStyle: body]))
            }
            for photo in entry.sortedPhotos {
                guard let attachment = pictureAttachment(photo.imageData ?? photo.thumbnailData) else { continue }
                let line = NSMutableAttributedString(attachment: attachment)
                line.append(NSAttributedString(string: "\n"))
                line.addAttributes([.font: book(12.5), .paragraphStyle: picture], range: NSRange(location: 0, length: line.length))
                text.append(line)
            }
        }
        return text
    }

    /// The size a picture is printed at: as large as fits the text box's width and
    /// `maxPictureHeight`, never enlarged.
    static func pictureSize(for size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return .zero }
        let scale = min(1, textBox.width / size.width, maxPictureHeight / size.height)
        return CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    }

    /// A picture sized for the page and downsampled to twice that size, which is sharp in print
    /// without carrying full-size photos into the file.
    private static func pictureAttachment(_ data: Data?) -> NSTextAttachment? {
        guard let data, let image = UIImage(data: data) else { return nil }
        let size = pictureSize(for: image.size)
        guard size != .zero else { return nil }
        let printed = PhotoProcessor.jpeg(image, maxDimension: max(size.width, size.height) * 2, quality: 0.8)
            .flatMap(UIImage.init(data:)) ?? image
        let attachment = NSTextAttachment(image: printed)
        attachment.bounds = CGRect(origin: .zero, size: size)
        return attachment
    }

    /// Lays text into the page's text box with TextKit, one text container per page, starting new
    /// pages until it's all set. A picture that doesn't fit at the foot of a page moves to the next.
    private static func flow(_ text: NSAttributedString, in context: UIGraphicsPDFRendererContext, newPage: () -> Void) {
        let storage = NSTextStorage(attributedString: text)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let box = textBox
        var isFirstPage = true
        while true {
            let container = NSTextContainer(size: box.size)
            container.lineFragmentPadding = 0
            layout.addTextContainer(container)
            let glyphs = layout.glyphRange(for: container)
            guard glyphs.length > 0 else { break }
            if !isFirstPage { newPage() }
            isFirstPage = false
            layout.drawBackground(forGlyphRange: glyphs, at: box.origin)
            layout.drawGlyphs(forGlyphRange: glyphs, at: box.origin)
            if NSMaxRange(glyphs) >= layout.numberOfGlyphs { break }
        }
    }

    // MARK: Drawing helpers

    /// IM Fell English, the app's book face (small capitals stand in for bold), falling back to
    /// the system serif.
    static func book(_ size: CGFloat, weight: UIFont.Weight = .regular, italic: Bool = false) -> UIFont {
        let name = italic ? BookFont.italic : (weight == .regular ? BookFont.roman : BookFont.smallCaps)
        if let font = UIFont(name: name, size: size) {
            return font
        }
        var descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        descriptor = descriptor.withDesign(.serif) ?? descriptor
        if italic, let slanted = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.traitItalic)) {
            descriptor = slanted
        }
        return UIFont(descriptor: descriptor, size: size)
    }

    @discardableResult
    private static func drawCentered(_ string: String, font: UIFont, color: UIColor, top: CGFloat, in rect: CGRect) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let text = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
        let height = text.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil).height
        text.draw(with: CGRect(x: rect.minX, y: top, width: rect.width, height: ceil(height)), options: [.usesLineFragmentOrigin], context: nil)
        return top + ceil(height)
    }

    private static func draw(_ string: String, font: UIFont, color: UIColor, centeredAt point: CGPoint) {
        let text = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
        let size = text.size()
        text.draw(at: CGPoint(x: point.x - size.width / 2, y: point.y))
    }
}
