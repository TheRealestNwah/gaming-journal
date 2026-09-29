import CoreText
import SwiftUI
import UIKit

/// A notebook typeset as a small printed book: a leather-coloured cover page, the party with
/// portraits, then the chronicle on parchment pages, one chapter after another.
enum PDFBook {
    /// A 6 × 9 inch trade paperback page.
    static let pageSize = CGSize(width: 432, height: 648)
    static let margin: CGFloat = 50

    private static let parchment = UIColor(red: 0.96, green: 0.91, blue: 0.85, alpha: 1)
    private static let ink = UIColor(red: 0.17, green: 0.11, blue: 0.08, alpha: 1)
    private static let fadedInk = UIColor(red: 0.42, green: 0.33, blue: 0.26, alpha: 1)
    private static let ember = UIColor(red: 0.66, green: 0.27, blue: 0.10, alpha: 1)
    private static let gold = UIColor(red: 0.66, green: 0.52, blue: 0.08, alpha: 1)

    static func render(_ notebook: Notebook, locale: Locale = .current) -> Data {
        let bounds = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format(for: notebook))
        return renderer.pdfData { context in
            var pageNumber = 0
            func newPage(numbered: Bool = true) {
                context.beginPage()
                pageNumber += 1
                parchment.setFill()
                context.fill(bounds)
                if numbered {
                    draw("\(pageNumber)", font: serif(9), color: fadedInk, centeredAt: CGPoint(x: bounds.midX, y: bounds.maxY - 28))
                }
            }

            newPage(numbered: false)
            drawCover(notebook, locale: locale, in: bounds)

            let party = notebook.party
            if !party.isEmpty {
                newPage()
                drawParty(party, in: bounds, newPage: { newPage() })
            }

            for section in sections(of: notebook) {
                newPage()
                flow(chronicle(section, locale: locale), in: context, newPage: { newPage() })
            }
        }
    }

    static func filename(for notebook: Notebook) -> String {
        NotebookMarkdown.filename(for: notebook)
    }

    // MARK: Structure

    /// A run of entries under one heading: each chapter, then loose pages; or the whole chronicle.
    struct Section {
        var title: String?
        var summary: String
        var entries: [Entry]
    }

    static func sections(of notebook: Notebook) -> [Section] {
        let story = (notebook.entries ?? []).sorted { ($0.writtenAt, $0.createdAt) < ($1.writtenAt, $1.createdAt) }
        let chapters = notebook.orderedChapters
        guard !chapters.isEmpty else {
            return story.isEmpty ? [] : [Section(title: nil, summary: "", entries: story)]
        }
        var sections = chapters.map { chapter in
            Section(title: chapter.title, summary: chapter.summary, entries: story.filter { $0.chapter?.id == chapter.id })
        }
        let chapterIDs = Set(chapters.map(\.id))
        let loose = story.filter { entry in entry.chapter.map { !chapterIDs.contains($0.id) } ?? true }
        if !loose.isEmpty {
            sections.append(Section(title: "Loose pages", summary: "", entries: loose))
        }
        return sections
    }

    // MARK: Pages

    private static func format(for notebook: Notebook) -> UIGraphicsPDFRendererFormat {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: notebook.title,
            kCGPDFContextCreator as String: "Gaming Journal",
        ]
        return format
    }

    private static func drawCover(_ notebook: Notebook, locale: Locale, in bounds: CGRect) {
        let leather = UIColor(notebook.coverStyle.colors.last ?? .brown)
        let band = bounds.insetBy(dx: 36, dy: 60)
        leather.setFill()
        UIBezierPath(roundedRect: band, cornerRadius: 12).fill()
        gold.setStroke()
        let tooled = UIBezierPath(roundedRect: band.insetBy(dx: 12, dy: 12), cornerRadius: 8)
        tooled.lineWidth = 1.5
        tooled.stroke()

        let cream = UIColor(red: 0.98, green: 0.95, blue: 0.89, alpha: 1)
        var y = band.minY + 120
        y = drawCentered(notebook.title, font: serif(28, weight: .bold), color: cream, top: y, in: band.insetBy(dx: 28, dy: 0))
        let subtitle = [notebook.gameTitle, notebook.platform].filter { !$0.isEmpty }.joined(separator: " · ")
        if !subtitle.isEmpty {
            y = drawCentered(subtitle, font: serif(13, italic: true), color: cream.withAlphaComponent(0.85), top: y + 10, in: band.insetBy(dx: 28, dy: 0))
        }
        var dateStyle = Date.FormatStyle(date: .long, time: .omitted)
        dateStyle.locale = locale
        let begun = "\(notebook.status.label) · begun \(notebook.startedAt.formatted(dateStyle))"
        y = drawCentered(begun, font: serif(10), color: cream.withAlphaComponent(0.75), top: y + 18, in: band.insetBy(dx: 28, dy: 0))
        if !notebook.summary.isEmpty {
            _ = drawCentered(notebook.summary, font: serif(11, italic: true), color: cream, top: y + 30, in: band.insetBy(dx: 40, dy: 0))
        }
    }

    private static func drawParty(_ party: [PartyMember], in bounds: CGRect, newPage: () -> Void) {
        let column = bounds.insetBy(dx: margin, dy: margin)
        var y = drawCentered("The Party", font: serif(20, weight: .bold), color: ink, top: column.minY, in: column) + 18
        let portrait: CGFloat = 54
        for member in party {
            let text = NSMutableAttributedString()
            text.append(NSAttributedString(string: member.name, attributes: [.font: serif(14, weight: .semibold), .foregroundColor: ink]))
            let role = [member.role, member.isRetired ? "retired" : ""].filter { !$0.isEmpty }.joined(separator: " · ")
            if !role.isEmpty {
                text.append(NSAttributedString(string: "\n\(role)", attributes: [.font: serif(10, italic: true), .foregroundColor: fadedInk]))
            }
            if !member.backstory.isEmpty {
                text.append(NSAttributedString(string: "\n\(member.backstory)", attributes: [.font: serif(10.5), .foregroundColor: ink]))
            }
            let textWidth = column.width - portrait - 14
            let height = max(portrait, text.boundingRect(with: CGSize(width: textWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil).height)
            if y + height > column.maxY - 20 {
                newPage()
                y = column.minY
            }
            let circle = CGRect(x: column.minX, y: y, width: portrait, height: portrait)
            if let data = member.portraitData, let image = UIImage(data: data) {
                UIGraphicsGetCurrentContext()?.saveGState()
                UIBezierPath(ovalIn: circle).addClip()
                image.draw(in: aspectFill(image.size, in: circle))
                UIGraphicsGetCurrentContext()?.restoreGState()
            } else {
                UIColor(hex: member.sigil.hex).setFill()
                UIBezierPath(ovalIn: circle).fill()
                draw(PartyRoster.initials(for: member.name), font: serif(18, weight: .semibold), color: .white, centeredAt: CGPoint(x: circle.midX, y: circle.midY - 11))
            }
            text.draw(with: CGRect(x: circle.maxX + 14, y: y, width: textWidth, height: height), options: [.usesLineFragmentOrigin], context: nil)
            y += height + 18
        }
    }

    /// The section's entries as one flowing run of text.
    private static func chronicle(_ section: Section, locale: Locale) -> NSAttributedString {
        let text = NSMutableAttributedString()
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        centered.paragraphSpacing = 6
        if let title = section.title {
            text.append(NSAttributedString(string: title + "\n", attributes: [.font: serif(20, weight: .bold), .foregroundColor: ink, .paragraphStyle: centered]))
            if !section.summary.isEmpty {
                text.append(NSAttributedString(string: section.summary + "\n", attributes: [.font: serif(11, italic: true), .foregroundColor: fadedInk, .paragraphStyle: centered]))
            }
            text.append(NSAttributedString(string: "\n", attributes: [.font: serif(8)]))
        }
        let heading = NSMutableParagraphStyle()
        heading.paragraphSpacingBefore = 14
        heading.paragraphSpacing = 2
        let body = NSMutableParagraphStyle()
        body.lineSpacing = 3
        body.paragraphSpacing = 7
        body.firstLineHeadIndent = 0

        var dateStyle = Date.FormatStyle(date: .long, time: .omitted)
        dateStyle.locale = locale
        for entry in section.entries {
            let title = entry.title.isEmpty ? entry.writtenAt.formatted(dateStyle) : entry.title
            text.append(NSAttributedString(
                string: (entry.isTurningPoint ? "✦ " : "") + title + "\n",
                attributes: [.font: serif(15, weight: .semibold), .foregroundColor: entry.isTurningPoint ? ember : ink, .paragraphStyle: heading]
            ))
            var meta = [entry.author?.name ?? "Narrator", entry.writtenAt.formatted(dateStyle)]
            if !entry.inGameDate.isEmpty { meta.append(entry.inGameDate) }
            if !entry.place.isEmpty { meta.append(entry.place) }
            if !entry.quest.isEmpty { meta.append("Quest: \(entry.quest)") }
            text.append(NSAttributedString(string: meta.joined(separator: " · ") + "\n", attributes: [.font: serif(9.5, italic: true), .foregroundColor: fadedInk]))
            let feelings = entry.emotions.compactMap { felt in felt.emotion.map { "\($0.label)\(String(repeating: "•", count: felt.intensity))" } }
            if !feelings.isEmpty {
                text.append(NSAttributedString(string: "Feeling: \(feelings.joined(separator: ", "))\n", attributes: [.font: serif(9.5), .foregroundColor: ember]))
            }
            let bonds = entry.bonds.map { "\($0.targetName) (\($0.affinityLabel.lowercased()))" }
            if !bonds.isEmpty {
                text.append(NSAttributedString(string: "Bonds: \(bonds.joined(separator: ", "))\n", attributes: [.font: serif(9.5), .foregroundColor: fadedInk]))
            }
            if !entry.body.isEmpty {
                text.append(NSAttributedString(string: entry.body + "\n", attributes: [.font: serif(11.5), .foregroundColor: ink, .paragraphStyle: body]))
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

    private static func serif(_ size: CGFloat, weight: UIFont.Weight = .regular, italic: Bool = false) -> UIFont {
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

    private static func aspectFill(_ size: CGSize, in rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let scale = max(rect.width / size.width, rect.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: rect.midX - fitted.width / 2, y: rect.midY - fitted.height / 2, width: fitted.width, height: fitted.height)
    }
}
