import SwiftUI

/// First-launch welcome, told like the opening page of an adventurer's journal.
struct OnboardingView: View {
    static let completedKey = "onboarding.completed"

    let onFinish: () -> Void

    var body: some View {
        ZStack {
            ParchmentBackground()
            EmberField(count: 18)
                .frame(maxHeight: .infinity, alignment: .bottom)

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 14) {
                        WaxSeal(systemImage: "book.closed.fill", size: 72)
                            .padding(.top, 48)
                        Text("Every adventure deserves a journal")
                            .font(Theme.title(.largeTitle))
                            .multilineTextAlignment(.center)
                        Text("Keep a notebook for each playthrough, and write it in your characters' own words.")
                            .font(Theme.prose)
                            .foregroundStyle(Theme.fadedInk)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        feature("books.vertical.fill", "A notebook per playthrough",
                                "Give each tale a leather cover, a game and a party of heroes.")
                        feature("pencil.and.scribble", "Write in character",
                                "Record what they did, how they felt, where they stood and who they trust.")
                        feature("flame.fill", "Watch them change",
                                "Follow each character's emotional arc, their bonds and the turning points of the story.")
                        feature("lock.fill", "Yours alone",
                                "Everything stays on this device unless you turn on iCloud sync.")
                    }
                    .parchmentCard(padding: 20)

                    Button(action: onFinish) {
                        Text("Begin your tale")
                    }
                    .buttonStyle(.ember)
                    .padding(.bottom, 32)
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(Theme.ink)
    }

    private func feature(_ systemImage: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Theme.ember)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.heading)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.fadedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView {}
}
