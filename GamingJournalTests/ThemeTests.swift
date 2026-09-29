import XCTest
import SwiftUI
import UIKit
@testable import GamingJournal

/// Keeps the warm palette readable: text colours must meet WCAG AA (4.5:1) on the surfaces they
/// sit on, in both light and dark mode.
final class ThemeContrastTests: XCTestCase {
    private func components(_ color: Color, dark: Bool) -> (Double, Double, Double) {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        let resolved = UIColor(color).resolvedColor(with: traits)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
    }

    private func luminance(_ color: Color, dark: Bool) -> Double {
        func channel(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let (r, g, b) = components(color, dark: dark)
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    private func contrast(_ a: Color, _ b: Color, dark: Bool) -> Double {
        let la = luminance(a, dark: dark)
        let lb = luminance(b, dark: dark)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    func testTextColoursMeetAAOnPageAndCards() {
        let text: [(String, Color)] = [
            ("ink", Theme.ink), ("fadedInk", Theme.fadedInk), ("ember", Theme.ember), ("crimson", Theme.crimson),
        ]
        let surfaces: [(String, Color)] = [("parchment", Theme.parchment), ("vellum", Theme.vellum)]
        for dark in [false, true] {
            for (textName, textColor) in text {
                for (surfaceName, surface) in surfaces {
                    let ratio = contrast(textColor, surface, dark: dark)
                    XCTAssertGreaterThanOrEqual(
                        ratio, 4.5,
                        "\(textName) on \(surfaceName) (\(dark ? "dark" : "light")) is \(String(format: "%.2f", ratio)):1"
                    )
                }
            }
        }
    }

    func testEmotionLabelsMeetAAInEveryFamily() {
        let surfaces: [(String, Color)] = [("parchment", Theme.parchment), ("vellum", Theme.vellum)]
        for dark in [false, true] {
            for group in EmotionGroup.allCases {
                for (surfaceName, surface) in surfaces {
                    let ratio = contrast(group.inkColor, surface, dark: dark)
                    XCTAssertGreaterThanOrEqual(
                        ratio, 4.5,
                        "\(group.label) on \(surfaceName) (\(dark ? "dark" : "light")) is \(String(format: "%.2f", ratio)):1"
                    )
                }
            }
        }
    }

    func testButtonLabelReadsOnEmberAndCrimson() {
        for dark in [false, true] {
            XCTAssertGreaterThanOrEqual(contrast(Theme.onEmber, Theme.ember, dark: dark), 4.5)
            XCTAssertGreaterThanOrEqual(contrast(Theme.onEmber, Theme.crimson, dark: dark), 4.5)
        }
    }

    func testSeededGeneratorIsDeterministic() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        XCTAssertEqual((0..<5).map { _ in a.next() }, (0..<5).map { _ in b.next() })
    }
}
