import SwiftUI

/// First-launch welcome: the opening page of a journal that hasn't been written yet.
struct OnboardingView: View {
    static let completedKey = "onboarding.completed"

    let onFinish: () -> Void

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(spacing: 22) {
                    WaxSeal(systemImage: "book.closed.fill", size: 76)
                        .padding(.top, 64)
                        .accessibilityHidden(true)
                    Text("Every hero keeps a journal")
                        .font(Theme.book(34, relativeTo: .largeTitle))
                        .foregroundStyle(Theme.ink)
                    PageRule()
                        .frame(maxWidth: 260)
                    Text("Start one for each character you play. Write their days in their own words, dated by the game's own calendar, and read them back like the journal in your pack.")
                        .font(Theme.book(19))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(4)
                    Text("Everything stays on this device unless you turn on iCloud sync.")
                        .font(Theme.bookItalic(16))
                        .foregroundStyle(Theme.fadedInk)
                    Button(action: onFinish) {
                        Text("Open the first page")
                            .font(Theme.book(22, relativeTo: .headline))
                            .foregroundStyle(Theme.rubric)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 28)
                            .overlay(Capsule().strokeBorder(Theme.rubric.opacity(0.6), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    OnboardingView {}
}
