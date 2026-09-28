import SwiftUI
import UIKit

/// Colour and type tokens for the warm, campfire-lit look. Views use these instead of raw colours
/// or fonts so light and dark mode stay consistent and readable.
enum Theme {
    // MARK: Colours

    /// Page background: warm parchment by day, charred wood by night.
    static let parchment = dynamic(light: 0xF4E9D8, dark: 0x1C1410)
    /// Raised surfaces such as cards and form rows.
    static let vellum = dynamic(light: 0xFBF4E6, dark: 0x2A1F18)
    /// Main text: dark ink, or bone white in dark mode.
    static let ink = dynamic(light: 0x2B1D14, dark: 0xF3E6D3)
    /// Secondary text.
    static let fadedInk = dynamic(light: 0x6B5443, dark: 0xBFA88F)
    /// Primary accent for buttons, selection and highlights.
    static let ember = dynamic(light: 0xA8441A, dark: 0xF07A3A)
    /// Text and icons placed on an ember or crimson fill.
    static let onEmber = dynamic(light: 0xFFFFFF, dark: 0x1C1410)
    /// Softer glow used in gradients and effects.
    static let emberGlow = dynamic(light: 0xE8913A, dark: 0xF2A541)
    /// Danger and deep accents.
    static let crimson = dynamic(light: 0x9E2A2B, dark: 0xE56B66)
    /// Ornaments, wax seals and ratings. Decorative only in light mode (below text contrast).
    static let gold = dynamic(light: 0xA88414, dark: 0xE0B84A)
    /// Hairlines and borders.
    static let rule = dynamic(light: 0xD9C6A5, dark: 0x4A3728)

    // MARK: Type

    /// Screen and notebook titles.
    static func title(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif).weight(.semibold)
    }

    /// Headings on cards and sections.
    static let heading = Font.system(.headline, design: .serif)
    /// Journal prose: entries, backstories, notes.
    static let prose = Font.system(.body, design: .serif)

    // MARK: Helpers

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// Serif navigation-bar titles and themed bars across the app. Call once at launch.
    static func applyAppearance() {
        let ink = UIColor(Self.ink)
        let titles: [NSAttributedString.Key: Any] = [.font: serifUIFont(.headline), .foregroundColor: ink]
        let largeTitles: [NSAttributedString.Key: Any] = [
            .font: serifUIFont(.largeTitle, weight: .semibold), .foregroundColor: ink,
        ]

        // Transparent over the parchment at rest; a blurred bar once content scrolls under it.
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

        let tabBar = UITabBarAppearance()
        tabBar.configureWithDefaultBackground()
        tabBar.backgroundColor = UIColor(Self.vellum).withAlphaComponent(0.92)
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar
    }

    private static func serifUIFont(_ style: UIFont.TextStyle, weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        let weighted = base.fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        let descriptor = weighted.withDesign(.serif) ?? weighted
        return UIFont(descriptor: descriptor, size: 0)
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
