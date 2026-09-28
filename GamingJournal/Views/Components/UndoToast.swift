import SwiftUI
import SwiftData

/// Holds the most recent deletion so it can be undone for a few seconds.
@Observable
@MainActor
final class UndoCenter {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
    }

    static let visibleSeconds: Double = 5

    private(set) var toast: Toast?
    @ObservationIgnored private var restore: (() -> Void)?
    @ObservationIgnored private var expiry: Task<Void, Never>?

    /// Shows `message` with an Undo button; a newer offer replaces an older one.
    func offer(_ message: String, restore: @escaping () -> Void) {
        let toast = Toast(message: message)
        self.toast = toast
        self.restore = restore
        expiry?.cancel()
        expiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.visibleSeconds))
            guard !Task.isCancelled, self?.toast == toast else { return }
            self?.dismiss()
        }
    }

    func undo() {
        restore?()
        dismiss()
    }

    func dismiss() {
        expiry?.cancel()
        toast = nil
        restore = nil
    }
}

struct UndoToastView: View {
    @Environment(UndoCenter.self) private var center

    var body: some View {
        if let toast = center.toast {
            HStack(spacing: 12) {
                Text(toast.message)
                    .font(.subheadline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Button("Undo") { center.undo() }
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
            .padding(.horizontal)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(toast.id)
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: "Undo") { center.undo() }
        }
    }
}

extension PlaySession {
    /// A detached copy with the same values and id, taken before deleting so undo can re-insert it.
    func restorableCopy() -> PlaySession {
        PlaySession(
            id: id,
            gameTitle: gameTitle,
            platform: platform,
            startDate: startDate,
            durationMinutes: durationMinutes,
            enjoyment: enjoyment,
            mood: mood,
            notes: notes,
            tags: tags,
            isMilestone: isMilestone,
            milestoneNote: milestoneNote,
            createdAt: createdAt
        )
    }
}

extension ModelContext {
    /// Deletes sessions and offers to put them back.
    @MainActor
    func deleteSessions(_ sessions: [PlaySession], undo center: UndoCenter) {
        guard !sessions.isEmpty else { return }
        let copies = sessions.map { $0.restorableCopy() }
        for session in sessions { delete(session) }
        try? save()
        let message = copies.count == 1 ? "Deleted \(copies[0].gameTitle) session" : "Deleted \(copies.count) sessions"
        center.offer(message) {
            for copy in copies { self.insert(copy) }
            try? self.save()
        }
    }
}
