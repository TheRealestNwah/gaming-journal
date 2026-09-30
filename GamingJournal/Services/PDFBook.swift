import CoreText
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

    /// Every entry as one flowing run of text: a date heading, then the words.
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

        for entry in entries {
            text.append(NSAttributedString(
                string: entry.heading(locale: locale) + "\n",
                attributes: [.font: book(13, weight: .semibold), .foregroundColor: rubric, .paragraphStyle: heading]
            ))
            if !entry.body.isEmpty {
                text.append(NSAttributedString(string: entry.body + "\n", attributes: [.font: book(12.5), .foregroundColor: ink, .paragraphStyle: body]))
            }
        }
        return text
    }

    /// Lays text into the page's text box, starting new pages until it's all set.
    private static func flow(_ text: NSAttributedString, in context: UIGraphicsPDFRendererContext, newPage: () -> Void) {
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let box = CGRect(origin: .zero, size: pageSize).insetBy(dx: margin, dy: margin)
        var location = 0
        while location < text.length {
            let cg = context.cgContext
            cg.saveGState()
            // Core Text draws with the origin at the bottom left.
            cg.textMatrix = .identity
            cg.translateBy(x: 0, y: pageSize.height)
            cg.scaleBy(x: 1, y: -1)
            let flipped = CGRect(x: box.minX, y: pageSize.height - box.maxY, width: box.width, height: box.height)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), CGPath(rect: flipped, transform: nil), nil)
            CTFrameDraw(frame, cg)
            cg.restoreGState()
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.length > 0 else { break }
            location += visible.length
            if location < text.length { newPage() }
        }
    }

    // MARK: Drawing helpers

    /// Baskerville, the app's book face, falling back to the system serif.
    static func book(_ size: CGFloat, weight: UIFont.Weight = .regular, italic: Bool = false) -> UIFont {
        let name = italic ? "Baskerville-Italic" : (weight == .regular ? "Baskerville" : "Baskerville-SemiBold")
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
