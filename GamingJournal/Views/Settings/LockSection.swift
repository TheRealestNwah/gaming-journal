import SwiftUI

/// Privacy settings: the journal lock (changing it asks the owner to authenticate first) and
/// whether the journal shows up in iOS search.
struct LockSection: View {
    @Environment(AppLock.self) private var lock
    @State private var isChanging = false
    @AppStorage(SpotlightIndex.enabledKey) private var spotlightEnabled = true

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
            Toggle("Show in Spotlight", systemImage: "magnifyingglass", isOn: $spotlightEnabled)
        } header: {
            Text("Privacy")
        } footer: {
            Text("The lock seals the journal whenever you leave the app: it hides from the app switcher, and the widget and iOS search stop showing your writing. Spotlight lets you find notebooks and entries from iOS search.")
        }
        .listRowBackground(Theme.vellum)
    }
}
