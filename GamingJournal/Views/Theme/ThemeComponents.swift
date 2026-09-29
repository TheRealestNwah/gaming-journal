import SwiftUI

// MARK: - Backgrounds

/// Parchment page with a faint paper grain, drawn in code so there are no image assets.
struct ParchmentBackground: View {
    var body: some View {
        Theme.parchment
            .overlay {
                Canvas { context, size in
                    guard size.width >= 1, size.height >= 1 else { return }
                    // Fixed seed so the grain doesn't shimmer between redraws.
                    var generator = SeededGenerator(seed: 0x5EED)
                    let specks = Int(size.width * size.height / 900)
                    for _ in 0..<specks {
                        let x = CGFloat.random(in: 0..<size.width, using: &generator)
                        let y = CGFloat.random(in: 0..<size.height, using: &generator)
                        let side = CGFloat.random(in: 0.6...1.6, using: &generator)
                        let opacity = Double.random(in: 0.03...0.08, using: &generator)
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: side, height: side)),
                            with: .color(Theme.fadedInk.opacity(opacity))
                        )
                    }
                }
                .allowsHitTesting(false)
            }
            .overlay {
                // Warm vignette toward the edges, like firelight on a page.
                RadialGradient(
                    colors: [.clear, Theme.emberGlow.opacity(0.08)],
                    center: .center,
                    startRadius: 200,
                    endRadius: 700
                )
                .allowsHitTesting(false)
            }
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

extension View {
    /// Parchment behind a List or Form, replacing the system grouped background.
    func parchmentBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(ParchmentBackground())
    }

    /// Raised vellum card with a hairline border.
    func parchmentCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.vellum, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.rule, lineWidth: 1)
            )
            .shadow(color: Theme.ink.opacity(0.08), radius: 6, y: 3)
    }
}

// MARK: - Buttons

/// Prominent call to action: a glowing ember gradient with serif label.
struct EmberButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.heading)
            .foregroundStyle(Theme.onEmber)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Theme.ember, Theme.crimson],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.6), lineWidth: 1))
            .shadow(color: Theme.ember.opacity(configuration.isPressed ? 0.2 : 0.4), radius: configuration.isPressed ? 4 : 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == EmberButtonStyle {
    static var ember: EmberButtonStyle { EmberButtonStyle() }
}

// MARK: - Ornaments

/// Wax seal marking a turning point or milestone.
struct WaxSeal: View {
    var systemImage = "flame.fill"
    var size: CGFloat = 28
    /// Spoken by VoiceOver; nil keeps the seal decorative.
    var label: String?

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.crimson.opacity(0.85), Theme.crimson],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size
                    )
                )
            Circle()
                .strokeBorder(Color.black.opacity(0.15), lineWidth: size * 0.08)
                .padding(size * 0.1)
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(Theme.gold)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.crimson.opacity(0.35), radius: 2, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "")
        .accessibilityHidden(label == nil)
    }
}

/// Section divider with a small diamond ornament and optional title.
struct SectionFlourish: View {
    var title: LocalizedStringKey?

    var body: some View {
        HStack(spacing: 10) {
            line
            Image(systemName: "diamond.fill")
                .font(.system(size: 6))
                .foregroundStyle(Theme.gold)
            if let title {
                Text(title)
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.fadedInk)
                    .textCase(.uppercase)
                    .tracking(1.5)
                Image(systemName: "diamond.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(Theme.gold)
            }
            line
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(title == nil ? [] : .isHeader)
    }

    private var line: some View {
        Rectangle()
            .fill(Theme.rule)
            .frame(height: 1)
    }
}

// MARK: - Covers

/// Leather cover colours for notebooks.
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

    var emblem: String {
        switch self {
        case .ember: "flame.fill"
        case .forest: "leaf.fill"
        case .frost: "snowflake"
        case .arcane: "sparkles"
        case .bloodMoon: "moon.fill"
        }
    }

    /// Dark-to-light leather tones; covers keep the same colours in light and dark mode.
    var colors: [Color] {
        switch self {
        case .ember: [Color(hex: 0x5A2412), Color(hex: 0x9C3F17)]
        case .forest: [Color(hex: 0x1E3322), Color(hex: 0x3D6340)]
        case .frost: [Color(hex: 0x1D2F42), Color(hex: 0x46698A)]
        case .arcane: [Color(hex: 0x2B1C44), Color(hex: 0x5C3F8C)]
        case .bloodMoon: [Color(hex: 0x3A0D12), Color(hex: 0x7E1C24)]
        }
    }
}

/// A leather-bound notebook cover with title, subtitle and emblem.
struct LeatherCover: View {
    let title: String
    var subtitle: String?
    var style: CoverStyle = .ember

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: style.colors, startPoint: .bottomLeading, endPoint: .topTrailing))
            // Spine shading.
            HStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 18)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            // Tooled border.
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color(hex: 0xE0B84A).opacity(0.55), lineWidth: 1)
                .padding(8)
                .padding(.leading, 10)

            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: style.emblem)
                    .font(.title3)
                    .foregroundStyle(Color(hex: 0xE0B84A))
                Spacer(minLength: 8)
                Text(title)
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .foregroundStyle(Color(hex: 0xF7ECD9))
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(Color(hex: 0xF7ECD9).opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 18)
            .padding(.leading, 28)
            .padding(.trailing, 16)
            // The cover keeps its shape, so its lettering stops growing at the largest text sizes;
            // the full title is in the label and on the notebook's own page.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .aspectRatio(0.72, contentMode: .fit)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 2, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(subtitle.map { "\(title), \($0)" } ?? title)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

#Preview("Components") {
    ScrollView {
        VStack(spacing: 24) {
            HStack(spacing: 16) {
                LeatherCover(title: "The Dragonborn's Road", subtitle: "Skyrim", style: .ember)
                LeatherCover(title: "Frostbound", subtitle: "Dark Souls", style: .frost)
            }
            SectionFlourish(title: "The Party")
            Text("We made camp beneath the old watchtower…")
                .font(Theme.prose)
                .parchmentCard()
            HStack {
                WaxSeal()
                WaxSeal(systemImage: "crown.fill", size: 40)
            }
            Button("Begin a new tale") {}
                .buttonStyle(.ember)
        }
        .padding()
    }
    .background(ParchmentBackground())
}
