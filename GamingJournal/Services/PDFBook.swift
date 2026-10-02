import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// A journal typeset as a small printed book: a leather cover page, then every entry on aged
/// pages under its date, set in the same book face as the app.
enum PDFBook {
    /// A 6 × 9 inch trade paperback page.
    static let pageSize = CGSize(width: 432, height: 648)
    static let margin: CGFloat = 50

    private static let paper = PlatformColor(red: 0.94, green: 0.89, blue: 0.78, alpha: 1)
    private static let ink = PlatformColor(red: 0.18, green: 0.13, blue: 0.09, alpha: 1)
    private static let fadedInk = PlatformColor(red: 0.37, green: 0.27, blue: 0.19, alpha: 1)
    private static let rubric = PlatformColor(red: 0.48, green: 0.18, blue: 0.11, alpha: 1)
    private static let gold = PlatformColor(red: 0.84, green: 0.71, blue: 0.42, alpha: 1)
    private static let cream = PlatformColor(red: 0.95, green: 0.90, blue: 0.80, alpha: 1)

    /// Everything the book prints, copied out of the store so it can be typeset off the main
    /// thread (a journal full of pictures takes a while).
    struct Book: Sendable {
        struct Page: Sendable {
            var heading: String
            var place: String
            var body: String
            var pictures: [Data]
        }

        var title: String
        var characterName: String
        var subtitle: String
        var coverStyle: CoverStyle
        var entries: [Page]

        init(_ journal: Journal, locale: Locale = .current) {
            title = journal.title
            characterName = journal.characterName
            subtitle = journal.subtitle
            coverStyle = journal.coverStyle
            entries = journal.story.map { entry in
                Page(
                    heading: entry.heading(locale: locale),
                    place: entry.place,
                    body: entry.body,
                    pictures: entry.sortedPhotos.compactMap { $0.imageData ?? $0.thumbnailData }
                )
            }
        }
    }

    static func render(_ journal: Journal, locale: Locale = .current) -> Data {
        render(Book(journal, locale: locale))
    }

    /// Typesets a copied-out book. Safe to call off the main thread.
    static func render(_ journal: Book) -> Data {
        let bounds = CGRect(origin: .zero, size: pageSize)
        #if os(macOS)
        let data = NSMutableData()
        var mediaBox = bounds
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, [
                kCGPDFContextTitle: journal.title,
                kCGPDFContextCreator: "Hearthbound",
              ] as CFDictionary) else { return Data() }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        var pageNumber = 0
        func newPage(numbered: Bool = true) {
            if pageNumber > 0 { context.restoreGState(); context.endPDFPage() }
            context.beginPDFPage(nil)
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            pageNumber += 1
            context.setFillColor(paper.cgColor)
            context.fill(bounds)
            if numbered {
                draw("\(pageNumber - 1)", font: book(10), color: fadedInk, centeredAt: CGPoint(x: bounds.midX, y: bounds.maxY - 30))
            }
        }
        newPage(numbered: false)
        drawCover(journal, in: bounds)
        if !journal.entries.isEmpty {
            newPage()
            flow(pages(journal.entries), newPage: { newPage() })
        }
        context.restoreGState()
        context.endPDFPage()
        context.closePDF()
        return data as Data
        #else
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

            if !journal.entries.isEmpty {
                newPage()
                flow(pages(journal.entries), newPage: { newPage() })
            }
        }
        #endif
    }

    static func filename(for journal: Journal) -> String {
        JournalMarkdown.filename(for: journal)
    }

    // MARK: Pages

    private static func drawCover(_ journal: Book, in bounds: CGRect) {
        let leather = PlatformColor(journal.coverStyle.colors.last ?? .brown)
        let band = bounds.insetBy(dx: 36, dy: 60)
        leather.setFill()
        #if os(macOS)
        NSBezierPath(roundedRect: band, xRadius: 12, yRadius: 12).fill()
        #else
        UIBezierPath(roundedRect: band, cornerRadius: 12).fill()
        #endif
        gold.setStroke()
        #if os(macOS)
        let tooled = NSBezierPath(roundedRect: band.insetBy(dx: 12, dy: 12), xRadius: 8, yRadius: 8)
        #else
        let tooled = UIBezierPath(roundedRect: band.insetBy(dx: 12, dy: 12), cornerRadius: 8)
        #endif
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
    static func pages(_ entries: [Book.Page]) -> NSAttributedString {
        let text = NSMutableAttributedString(string: "")
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
                string: entry.heading + "\n",
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
            for imageData in entry.pictures {
                guard let attachment = pictureAttachment(imageData) else { continue }
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
        guard let data, let image = PlatformImage(data: data) else { return nil }
        let size = pictureSize(for: image.size)
        guard size != .zero else { return nil }
        let printed = PhotoProcessor.jpeg(image, maxDimension: max(size.width, size.height) * 2, quality: 0.8)
            .flatMap(PlatformImage.init(data:)) ?? image
        #if os(macOS)
        let attachment = NSTextAttachment()
        guard let sized = printed.copy() as? NSImage else { return nil }
        sized.size = size
        attachment.attachmentCell = NSTextAttachmentCell(imageCell: sized)
        #else
        let attachment = NSTextAttachment(image: printed)
        attachment.bounds = CGRect(origin: .zero, size: size)
        #endif
        return attachment
    }

    /// Lays text into the page's text box with TextKit, one text container per page, starting new
    /// pages until it's all set. A picture that doesn't fit at the foot of a page moves to the next.
    private static func flow(_ text: NSAttributedString, newPage: () -> Void) {
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
    static func book(_ size: CGFloat, weight: PlatformFont.Weight = .regular, italic: Bool = false) -> PlatformFont {
        let name = italic ? BookFont.italic : (weight == .regular ? BookFont.roman : BookFont.smallCaps)
        if let font = PlatformFont(name: name, size: size) {
            return font
        }
        #if os(macOS)
        let fallback = NSFont.systemFont(ofSize: size, weight: weight)
        return italic ? NSFontManager.shared.convert(fallback, toHaveTrait: .italicFontMask) : fallback
        #else
        var descriptor = PlatformFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        descriptor = descriptor.withDesign(.serif) ?? descriptor
        if italic, let slanted = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.traitItalic)) {
            descriptor = slanted
        }
        return PlatformFont(descriptor: descriptor, size: size)
        #endif
    }

    @discardableResult
    private static func drawCentered(_ string: String, font: PlatformFont, color: PlatformColor, top: CGFloat, in rect: CGRect) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let text = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
        let height = text.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil).height
        text.draw(with: CGRect(x: rect.minX, y: top, width: rect.width, height: ceil(height)), options: [.usesLineFragmentOrigin], context: nil)
        return top + ceil(height)
    }

    private static func draw(_ string: String, font: PlatformFont, color: PlatformColor, centeredAt point: CGPoint) {
        let text = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
        let size = text.size()
        text.draw(at: CGPoint(x: point.x - size.width / 2, y: point.y))
    }
}
