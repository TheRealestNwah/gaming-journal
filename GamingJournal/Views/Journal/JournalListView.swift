import SwiftUI
import SwiftData

/// The journal timeline: sessions grouped by month and day, with search and filters.
struct JournalListView: View {
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undoCenter
    @Environment(LiveTimer.self) private var timer
    @Query(sort: \PlaySession.startDate, order: .reverse) private var sessions: [PlaySession]
    @State private var isAdding = false
    @State private var filter = JournalFilter()
    @State private var isStartingTimer = false
    @State private var finishedTimer: FinishedTimer?

    /// The session a stopped timer produced, waiting for review in the editor.
    private struct FinishedTimer: Identifiable {
        let id = UUID()
        let draft: SessionDraft
    }

    private var filtered: [PlaySession] {
        filter.apply(to: sessions)
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "gamecontroller",
                        description: Text("Log a play session to start your journal.")
                    )
                } else {
                    timeline
                }
            }
            .navigationTitle("Journal")
            .navigationDestination(for: PlaySession.self) { session in
                SessionDetailView(session: session)
            }
            .searchable(text: $filter.searchText, prompt: "Titles, notes, tags")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    JournalFilterMenu(filter: $filter, facets: JournalFacets(sessions: sessions))
                        .disabled(sessions.isEmpty)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if !timer.isActive {
                        Button("Start Timer", systemImage: "timer") { isStartingTimer = true }
                    }
                    Button("Add Session", systemImage: "plus") { isAdding = true }
                }
            }
            .sheet(isPresented: $isAdding) {
                SessionEditorView()
            }
            .sheet(isPresented: $isStartingTimer) {
                StartTimerSheet()
                    .environment(timer)
            }
            .sheet(item: $finishedTimer) { finished in
                SessionEditorView(prefill: finished.draft) { timer.clear() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                UndoToastView()
                TimerBanner { draft in finishedTimer = FinishedTimer(draft: draft) }
            }
            .animation(.spring(duration: 0.3), value: undoCenter.toast)
            .animation(.spring(duration: 0.3), value: timer.state)
        }
    }

    @ViewBuilder
    private var timeline: some View {
        let months = TimelineGrouping.months(from: filtered)
        if months.isEmpty {
            ContentUnavailableView {
                Label("No matching sessions", systemImage: "magnifyingglass")
            } description: {
                Text("Try a different search or clear the filters.")
            } actions: {
                Button("Clear Filters") { filter = JournalFilter() }
            }
        } else {
            List {
                if filter.hasFacets {
                    ActiveFilterBar(filter: $filter)
                }
                ForEach(months) { month in
                    ForEach(month.days) { day in
                        Section {
                            ForEach(day.sessions) { session in
                                NavigationLink(value: session) {
                                    SessionRowView(session: session)
                                }
                            }
                            .onDelete { offsets in
                                context.deleteSessions(offsets.map { day.sessions[$0] }, undo: undoCenter)
                            }
                        } header: {
                            DayHeader(
                                day: day,
                                month: day.id == month.days.first?.id ? month : nil
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

/// Day title and total; the first day of each month also carries the month name and its total.
private struct DayHeader: View {
    let day: TimelineGrouping.Day
    let month: TimelineGrouping.Month?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let month {
                HStack(alignment: .firstTextBaseline) {
                    Text(month.date, format: .dateTime.month(.wide).year())
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(PlaytimeFormatter.string(fromMinutes: month.totalMinutes))
                        .font(.subheadline.monospacedDigit())
                }
                .padding(.top, 8)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
            HStack {
                Text(dayTitle)
                Spacer()
                Text(PlaytimeFormatter.string(fromMinutes: day.totalMinutes))
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        }
        .textCase(nil)
    }

    private var dayTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day.date) { return "Today" }
        if calendar.isDateInYesterday(day.date) { return "Yesterday" }
        return day.date.formatted(.dateTime.weekday(.wide).day().month())
    }
}

/// Removable capsules for each active facet.
private struct ActiveFilterBar: View {
    @Binding var filter: JournalFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let game = filter.game {
                    chip(game, systemImage: "gamecontroller") { filter.game = nil }
                }
                if let platform = filter.platform {
                    chip(platform, systemImage: "display") { filter.platform = nil }
                }
                if let tag = filter.tag {
                    chip("#\(tag)", systemImage: "tag") { filter.tag = nil }
                }
                if filter.milestonesOnly {
                    chip("Milestones", systemImage: "flag") { filter.milestonesOnly = false }
                }
                Button("Clear") { filter.clearFacets() }
                    .font(.subheadline)
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    private func chip(_ title: String, systemImage: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            HStack(spacing: 4) {
                Label(title, systemImage: systemImage)
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .accessibilityLabel("Remove filter \(title)")
    }
}

/// Toolbar menu for picking the game, platform and tag facets.
private struct JournalFilterMenu: View {
    @Binding var filter: JournalFilter
    let facets: JournalFacets

    var body: some View {
        Menu {
            facetPicker("Game", systemImage: "gamecontroller", values: facets.games, selection: $filter.game)
            facetPicker("Platform", systemImage: "display", values: facets.platforms, selection: $filter.platform)
            facetPicker("Tag", systemImage: "tag", values: facets.tags, selection: $filter.tag)
            Toggle("Milestones Only", systemImage: "flag", isOn: $filter.milestonesOnly)
            if filter.hasFacets {
                Divider()
                Button("Clear Filters", systemImage: "xmark", role: .destructive) { filter.clearFacets() }
            }
        } label: {
            Label(
                "Filter",
                systemImage: filter.hasFacets
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
    }

    @ViewBuilder
    private func facetPicker(
        _ title: String,
        systemImage: String,
        values: [String],
        selection: Binding<String?>
    ) -> some View {
        if !values.isEmpty {
            Picker(selection: selection) {
                Text("Any").tag(String?.none)
                ForEach(values, id: \.self) { value in
                    Text(value).tag(String?.some(value))
                }
            } label: {
                Label(title, systemImage: systemImage)
            }
            .pickerStyle(.menu)
        }
    }
}

#Preview {
    JournalListView()
        .environment(UndoCenter())
        .environment(LiveTimer(defaults: UserDefaults(suiteName: "preview")!))
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
}
