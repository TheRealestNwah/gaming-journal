import SwiftUI
import SwiftData

/// Every game played, derived from sessions.
struct GamesView: View {
    @Query private var sessions: [PlaySession]
    @State private var order: GameLibrary.SortOrder = .recent
    @State private var searchText = ""

    private var games: [GameSummary] {
        let all = GameLibrary.summaries(from: sessions, sortedBy: order)
        let needle = GameTitleIndex.key(for: searchText)
        return needle.isEmpty ? all : all.filter { $0.key.contains(needle) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No games yet",
                        systemImage: "square.stack",
                        description: Text("Games appear here once you log a session.")
                    )
                } else if games.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(games) { game in
                        NavigationLink(value: game.key) {
                            GameRow(game: game)
                        }
                    }
                }
            }
            .navigationTitle("Games")
            .navigationDestination(for: String.self) { key in
                GameDetailView(key: key)
            }
            .navigationDestination(for: PlaySession.self) { session in
                SessionDetailView(session: session)
            }
            .searchable(text: $searchText, prompt: "Game title")
            .toolbar {
                Menu {
                    Picker("Sort By", selection: $order) {
                        ForEach(GameLibrary.SortOrder.allCases) { order in
                            Text(order.label).tag(order)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .disabled(sessions.isEmpty)
            }
        }
        .sessionOverlays()
    }
}

private struct GameRow: View {
    let game: GameSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(game.title).font(.headline)
                Spacer()
                Text(PlaytimeFormatter.string(fromMinutes: game.totalMinutes))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Text("\(game.sessionCount) session\(game.sessionCount == 1 ? "" : "s")")
                Text("·")
                Text(game.lastPlayed, format: .relative(presentation: .named))
                if let platform = game.platforms.first {
                    Text("·")
                    Text(platform)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One game's totals and its sessions, with rename/merge.
struct GameDetailView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlaySession.startDate, order: .reverse) private var allSessions: [PlaySession]
    @State private var key: String
    @State private var isRenaming = false
    @State private var newTitle = ""

    init(key: String) {
        _key = State(initialValue: key)
    }

    private var sessions: [PlaySession] {
        GameLibrary.sessions(forKey: key, in: allSessions)
    }

    private var summary: GameSummary? {
        GameLibrary.summaries(from: sessions).first
    }

    var body: some View {
        Group {
            if let summary {
                List {
                    Section {
                        StatGrid(summary: summary)
                    }
                    Section("Sessions") {
                        ForEach(sessions) { session in
                            NavigationLink(value: session) {
                                SessionRowView(session: session)
                            }
                        }
                    }
                }
                .navigationTitle(summary.title)
                .toolbar {
                    Button("Rename") {
                        newTitle = summary.title
                        isRenaming = true
                    }
                }
                .alert("Rename Game", isPresented: $isRenaming) {
                    TextField("Title", text: $newTitle)
                    Button("Cancel", role: .cancel) {}
                    Button("Rename") { rename(from: summary.title) }
                } message: {
                    Text(renameMessage(for: summary))
                }
            } else {
                ContentUnavailableView("No sessions", systemImage: "square.stack")
            }
        }
        .navigationBarTitleDisplayMode(.large)
    }

    private func renameMessage(for summary: GameSummary) -> String {
        "Changes the title on all \(summary.sessionCount) session\(summary.sessionCount == 1 ? "" : "s"). "
            + "Using another game's title merges the two."
    }

    private func rename(from oldTitle: String) {
        guard let written = GameLibrary.rename(oldTitle, to: newTitle, in: allSessions) else { return }
        try? context.save()
        key = GameTitleIndex.key(for: written)
    }
}

private struct StatGrid: View {
    let summary: GameSummary

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                stat("Total", PlaytimeFormatter.string(fromMinutes: summary.totalMinutes))
                stat("Sessions", "\(summary.sessionCount)")
            }
            GridRow {
                stat("First played", summary.firstPlayed.formatted(date: .abbreviated, time: .omitted))
                stat("Last played", summary.lastPlayed.formatted(date: .abbreviated, time: .omitted))
            }
            GridRow {
                stat("Avg. enjoyment", summary.averageEnjoyment.map { String(format: "%.1f ★", $0) } ?? "—")
                stat("Milestones", "\(summary.milestoneCount)")
            }
            if !summary.platforms.isEmpty {
                GridRow {
                    stat("Platforms", summary.platforms.joined(separator: ", "))
                        .gridCellColumns(2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
