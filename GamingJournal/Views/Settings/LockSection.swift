import SwiftUI

/// Settings for the journal lock. Changing it asks the owner to authenticate first.
struct LockSection: View {
    @Environment(AppLock.self) private var lock
    @State private var isChanging = false

    var body: some View {
        Section {
            Toggle("Lock with \(lock.method)", systemImage: "lock", isOn: Binding(
                get: { lock.isEnabled },
                set: { enabled in
                    isChanging = true
                    Task {
                        await lock.setEnabled(enabled)
                        isChanging = false
                    }
                }
            ))
            .disabled(isChanging)
        } header: {
            Text("Privacy")
        } footer: {
            Text("Seal the journal whenever you leave the app. It hides from the app switcher, and the latest-entry widget stops showing your writing.")
        }
        .listRowBackground(Theme.vellum)
    }
}
