import SwiftUI

/// First-launch welcome: what the app does, then straight in.
struct OnboardingView: View {
    static let completedKey = "onboarding.completed"

    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 24)
            VStack(spacing: 12) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text("Gaming Journal")
                    .font(.largeTitle.bold())
                Text("A diary of the games you play.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 20) {
                feature("book", "Log every session", "Game, platform, time played, how it felt and what happened.")
                feature("timer", "Time as you play", "Start a timer, and stop it to log the session. It keeps running if you leave the app.")
                feature("chart.bar", "See your habits", "Hours per week, favourite games, streaks and a heatmap.")
                feature("lock", "Private by default", "Everything stays on your device unless you turn on iCloud sync.")
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 24)

            Button(action: onFinish) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .frame(maxWidth: 520)
    }

    private func feature(_ systemImage: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView {}
}
