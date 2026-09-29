import SwiftUI

/// Settings for the campfire reminders. Turning one on asks for notification permission; if
/// that's refused the switch goes back off and says why.
struct RemindersSection: View {
    @AppStorage(CampfireReminders.afterSessionKey) private var afterSession = false
    @AppStorage(CampfireReminders.eveningKey) private var evening = false
    @AppStorage(CampfireReminders.eveningTimeKey) private var eveningTime = CampfireReminders.defaultEveningTime
    @State private var permissionRefused = false
    private let reminders = CampfireReminders.shared

    var body: some View {
        Section {
            Toggle("After a session", systemImage: "hourglass", isOn: $afterSession)
            Toggle("Every evening", systemImage: "moon.stars", isOn: $evening)
            if evening {
                DatePicker("Time", selection: eveningDate, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Campfire reminders")
        } footer: {
            Text(permissionRefused
                 ? "Notifications are off for Hearthbound. Turn them on in the Settings app to get reminders."
                 : "After a session, choose \"Remind me later\" and you'll get a nudge an hour on, unless you've written by then. The evening reminder comes every day at the time you pick.")
        }
        .listRowBackground(Theme.vellum)
        .onChange(of: afterSession) { _, isOn in
            if isOn { confirmPermission { afterSession = false } }
        }
        .onChange(of: evening) { _, isOn in
            if isOn {
                confirmPermission { evening = false }
            } else {
                Task { await reminders.applyEveningSetting() }
            }
        }
        .onChange(of: eveningTime) {
            Task { await reminders.applyEveningSetting() }
        }
    }

    /// The time picker works in dates; the setting is minutes after midnight.
    private var eveningDate: Binding<Date> {
        Binding {
            Calendar.current.date(from: CampfireReminders.eveningComponents(minutes: eveningTime)) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            eveningTime = (parts.hour ?? 21) * 60 + (parts.minute ?? 0)
        }
    }

    private func confirmPermission(orUndo undo: @escaping () -> Void) {
        Task {
            let granted = await reminders.enable()
            permissionRefused = !granted
            if granted {
                await reminders.applyEveningSetting()
            } else {
                undo()
            }
        }
    }
}
