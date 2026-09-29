import SwiftUI
import UIKit

/// Colour and type tokens for the in-game journal look: aged paper and ink for the pages, dark
/// wood for the shelf. Pages stay paper in dark mode, just dimmer, like a book read by candlelight.
enum Theme {
    // MARK: Pages

    /// Aged paper.
    static let paper = dynamic(light: 0xEFE2C6, dark: 0xC2AE88)
    /// The darker, scorched edge of a page.
    static let paperEdge = dynamic(light: 0xC9AC7C, dark: 0x8E7652)
    /// Written text.
    static let ink = dynamic(light: 0x2E2117, dark: 0x1E150E)
    /// Captions, page numbers and hints.
    static let fadedInk = dynamic(light: 0x5E4631, dark: 0x3E2C1C)
    /// Red ink for dates and actions, like a scribe's rubric.
    static let rubric = dynamic(light: 0x7A2E1C, dark: 0x5E1F12)

    // MARK: Shelf

    /// Dark wood behind the shelf of journals, in both modes.
    static let wood = Color(hex: 0x21160F)
    static let woodLight = Color(hex: 0x33241A)
    /// Text on wood.
    static let woodInk = Color(hex: 0xEADBC0)
    static let woodFaded = Color(hex: 0xB8A283)
    /// Gilt: clasps, tooling and actions on the shelf.
    static let gold = Color(hex: 0xD6B46A)
    /// Sealing wax.
    static let wax = Color(hex: 0x8E2A1C)

    // MARK: Type

    /// Baskerville, a book face that ships with iOS, scaled with Dynamic Type.
    static func book(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Baskerville", size: size, relativeTo: style)
    }

    static func bookItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Baskerville-Italic", size: size, relativeTo: style)
    }

    static func bookBold(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Baskerville-SemiBold", size: size, relativeTo: style)
    }

    /// Entry text on a page.
    static let prose = book(19)
    /// The date above an entry.
    static let dateLine = bookBold(17, relativeTo: .headline)
    /// Small-caps style controls on a page ("‹ Journals", "Next ›").
    static let pageControl = book(17, relativeTo: .callout)

    // MARK: Helpers

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// Book-face navigation titles and a quiet navigation bar. Call once at launch.
    static func applyAppearance() {
        let titles: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Baskerville-SemiBold", size: 18) ?? .preferredFont(forTextStyle: .headline),
        ]
        let largeTitles: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Baskerville", size: 34) ?? .preferredFont(forTextStyle: .largeTitle),
        ]
        let atRest = UINavigationBarAppearance()
        atRest.configureWithTransparentBackground()
        atRest.titleTextAttributes = titles
        atRest.largeTitleTextAttributes = largeTitles
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.titleTextAttributes = titles
        scrolled.largeTitleTextAttributes = largeTitles
        UINavigationBar.appearance().scrollEdgeAppearance = atRest
        UINavigationBar.appearance().standardAppearance = scrolled
        UINavigationBar.appearance().compactAppearance = scrolled
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}
