import SwiftUI

// MARK: - Backgrounds

/// An aged page: warm paper that darkens toward scorched edges, with a faint grain drawn in code.
struct PaperBackground: View {
    var body: some View {
        ZStack {
            Theme.paper
            RadialGradient(
                colors: [.clear, .clear, Theme.paperEdge.opacity(0.55), Theme.paperEdge],
                center: .center,
                startRadius: 0,
                endRadius: 620
            )
            Canvas { context, size in
                guard size.width >= 1, size.height >= 1 else { return }
                // Fixed seed so the grain doesn't shimmer between redraws.
                var generator = SeededGenerator(seed: 0x5EED)
                let specks = Int(size.width * size.height / 700)
                for _ in 0..<specks {
                    let x = CGFloat.random(in: 0..<size.width, using: &generator)
                    let y = CGFloat.random(in: 0..<size.height, using: &generator)
                    let side = CGFloat.random(in: 0.6...1.8, using: &generator)
                    let opacity = Double.random(in: 0.04...0.10, using: &generator)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: side, height: side)),
                        with: .color(Theme.fadedInk.opacity(opacity))
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Dark wood behind the shelf.
struct WoodBackground: View {
    var body: some View {
        LinearGradient(colors: [Theme.woodLight, Theme.wood], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// Small deterministic random generator (SplitMix64) for decorative drawing.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A thin rule that fades out at both ends, drawn under a page's title.
struct PageRule: View {
    var body: some View {
        LinearGradient(colors: [.clear, Theme.fadedInk.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

// MARK: - Covers

/// Leather colours for a journal's cover.
enum CoverStyle: String, CaseIterable, Identifiable, Codable {
    case ember, forest, frost, arcane, bloodMoon

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ember: "Ember"
        case .forest: "Forest"
        case .frost: "Frost"
        case .arcane: "Arcane"
        case .bloodMoon: "Blood Moon"
        }
    }

    /// Dark-to-light leather tones; covers keep the same colours in light and dark mode.
    var colors: [Color] {
        switch self {
        case .ember: [Color(hex: 0x5A2412), Color(hex: 0x8C3A17)]
        case .forest: [Color(hex: 0x1E3322), Color(hex: 0x3D6340)]
        case .frost: [Color(hex: 0x1D2F42), Color(hex: 0x3F5F80)]
        case .arcane: [Color(hex: 0x2B1C44), Color(hex: 0x5C3F8C)]
        case .bloodMoon: [Color(hex: 0x3A0D12), Color(hex: 0x7E1C24)]
        }
    }
}

/// A journal lying on the shelf: a leather band with the character's name and a gilt clasp.
struct ShelfBook: View {
    let name: String
    var subtitle: String = ""
    var style: CoverStyle = .ember

    private let cream = Color(hex: 0xF3E6CC)

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(Theme.book(25, relativeTo: .title2))
                    .foregroundStyle(cream)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.bookItalic(15, relativeTo: .subheadline))
                        .foregroundStyle(cream.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(.leading, 34)
            .padding(.vertical, 22)
            Spacer(minLength: 12)
            // The gilt clasp.
            LinearGradient(colors: [Color(hex: 0x8A6A2A), Theme.gold, Color(hex: 0x8A6A2A)], startPoint: .leading, endPoint: .trailing)
                .frame(width: 10)
                .opacity(0.85)
                .padding(.trailing, 26)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .background {
            ZStack(alignment: .leading) {
                LinearGradient(colors: style.colors, startPoint: .bottomLeading, endPoint: .topTrailing)
                // The spine.
                LinearGradient(colors: [.black.opacity(0.45), .black.opacity(0.05)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 22)
            }
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 6, bottomTrailingRadius: 10, topTrailingRadius: 10))
        .shadow(color: .black.opacity(0.5), radius: 6, y: 5)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Seals

/// A round wax seal with a gilt mark, for the quill button and the lock.
struct WaxSeal: View {
    var systemImage = "pencil.and.scribble"
    var size: CGFloat = 58

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xA33A2A), Theme.wax], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.7))
            Circle()
                .strokeBorder(.black.opacity(0.15), lineWidth: size * 0.05)
                .padding(size * 0.08)
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(Theme.gold)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(hex: 0x3C140A).opacity(0.45), radius: 5, y: 3)
    }
}

#Preview("Components") {
    ZStack {
        PaperBackground()
        VStack(spacing: 24) {
            ShelfBook(name: "Eira Stormborn", subtitle: "Nord · Skyrim", style: .ember)
            Text("16th of Last Seed, 4E 201").font(Theme.dateLine).foregroundStyle(Theme.rubric)
            Text("The cart ride ended at a headsman's block.").font(Theme.prose)
            WaxSeal()
        }
        .padding()
    }
}
