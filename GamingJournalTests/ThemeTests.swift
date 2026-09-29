import XCTest
import SwiftUI
import UIKit
@testable import GamingJournal

/// Keeps the pages and the shelf readable: text colours must meet WCAG AA (4.5:1) on the surfaces
/// they sit on, in both light and dark mode.
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

    func testPageTextMeetsAAOnPaper() {
        let text: [(String, Color)] = [("ink", Theme.ink), ("fadedInk", Theme.fadedInk), ("rubric", Theme.rubric)]
        for dark in [false, true] {
            for (name, color) in text {
                let ratio = contrast(color, Theme.paper, dark: dark)
                XCTAssertGreaterThanOrEqual(
                    ratio, 4.5,
                    "\(name) on paper (\(dark ? "dark" : "light")) is \(String(format: "%.2f", ratio)):1"
                )
            }
        }
    }

    func testShelfTextMeetsAAOnWood() {
        let text: [(String, Color)] = [("woodInk", Theme.woodInk), ("woodFaded", Theme.woodFaded), ("gold", Theme.gold)]
        for (name, color) in text {
            for surface in [Theme.wood, Theme.woodLight] {
                let ratio = contrast(color, surface, dark: false)
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(name) on wood is \(String(format: "%.2f", ratio)):1")
            }
        }
    }

    func testSeededGeneratorIsDeterministic() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        XCTAssertEqual((0..<5).map { _ in a.next() }, (0..<5).map { _ in b.next() })
    }
}
