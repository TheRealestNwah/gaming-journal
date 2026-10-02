#if os(iOS)
import SwiftUI
import UIKit

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

    private enum Cover: Equatable {
        case none, sealed, locked
    }

    private var cover: Cover {
        if lock.isLocked { return .locked }
        // What the app switcher snapshots: no pages on show.
        if lock.isEnabled && scenePhase != .active { return .sealed }
        return .none
    }

    func body(content: Content) -> some View {
        content
            // In its own window so it covers sheets and alerts too, not just the root view.
            .onChange(of: cover, initial: true) { _, cover in
                switch cover {
                case .none: LockWindow.shared.hide()
                case .sealed: LockWindow.shared.show(SealedCover())
                case .locked: LockWindow.shared.show(LockScreen(lock: lock))
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

/// A window above everything else in the app (sheets, alerts, the keyboard) for the lock.
@MainActor
private final class LockWindow {
    static let shared = LockWindow()
    private var window: UIWindow?

    func show(_ view: some View) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState != .unattached })
        else { return }
        let window = window ?? UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        let host = UIHostingController(rootView: AnyView(view))
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = false
        self.window = window
    }

    func hide() {
        window?.isHidden = true
        window = nil
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
                WaxSeal(systemImage: "lock.fill", size: 88)
                    .accessibilityLabel("Sealed")
                Text("Your journals are sealed")
                    .font(Theme.book(28, relativeTo: .title2))
                    .foregroundStyle(Theme.woodInk)
                Text("Only you can break the seal.")
                    .font(Theme.bookItalic(18))
                    .foregroundStyle(Theme.woodFaded)
                Button("Unlock with \(lock.method)") {
                    Task { await lock.unlock() }
                }
                .font(Theme.book(20, relativeTo: .headline))
                .foregroundStyle(Theme.gold)
                .padding(.top, 8)
                Spacer()
            }
            .multilineTextAlignment(.center)
            .padding(32)
        }
        .task { await lock.unlock() }
    }
}

/// The closed shelf over everything.
private struct SealedCover: View {
    var body: some View {
        WoodBackground()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

#endif
