import SwiftUI

extension View {
    /// Covers the app while the journal is locked, and hides it in the app switcher when the lock
    /// is on. Seals again whenever the app goes to the background.
    func appLock(_ lock: AppLock) -> some View {
        modifier(AppLockModifier(lock: lock))
    }
}

private struct AppLockModifier: ViewModifier {
    let lock: AppLock
    @Environment(\.scenePhase) private var scenePhase
    /// Only a return from the background should prompt: the Face ID sheet itself makes the app
    /// briefly inactive, and prompting on that would loop after a cancel.
    @State private var returningFromBackground = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if lock.isLocked {
                    LockScreen(lock: lock)
                } else if lock.isEnabled && scenePhase != .active {
                    // What the app switcher snapshots: no pages on show.
                    SealedCover()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    lock.seal()
                    returningFromBackground = true
                case .active where returningFromBackground:
                    returningFromBackground = false
                    Task { await lock.unlock() }
                default:
                    break
                }
            }
    }
}

/// The closed journal, with a way to open it.
private struct LockScreen: View {
    let lock: AppLock

    var body: some View {
        ZStack {
            SealedCover()
            VStack(spacing: 20) {
                Spacer()
                WaxSeal(systemImage: "lock.fill", size: 88, label: "Sealed")
                Text("Your journal is sealed")
                    .font(Theme.title(.title2))
                    .foregroundStyle(Theme.ink)
                Text("Only you can break the seal.")
                    .font(Theme.prose)
                    .foregroundStyle(Theme.fadedInk)
                Button("Unlock with \(lock.method)") {
                    Task { await lock.unlock() }
                }
                .buttonStyle(.ember)
                .frame(maxWidth: 320)
                Spacer()
            }
            .padding(32)
        }
        .task { await lock.unlock() }
    }
}

/// Plain parchment over everything.
private struct SealedCover: View {
    var body: some View {
        ParchmentBackground()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
