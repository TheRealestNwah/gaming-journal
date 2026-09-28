import SwiftUI

/// Library search: matching notebooks, each with the entries that mention the words.
struct LibrarySearchResults: View {
    let query: String
    let notebooks: [Notebook]

    var body: some View {
        let results = LibrarySearch.results(for: query, in: notebooks)
        if results.isEmpty {
            ContentUnavailableView {
                Label("Nothing written of that", systemImage: "magnifyingglass")
            } description: {
                Text("No notebook or entry mentions “\(query)”.")
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(results) { result in
                        section(result)
                    }
                }
                .padding()
            }
        }
    }

    private func section(_ result: LibrarySearch.Result) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: result.notebook) {
                HStack(spacing: 12) {
                    LeatherCover(title: result.notebook.title, style: result.notebook.coverStyle)
                        .frame(width: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.notebook.title)
                            .font(Theme.heading)
                            .foregroundStyle(Theme.ink)
                        Text(summary(of: result))
                            .font(.caption)
                            .foregroundStyle(Theme.fadedInk)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.fadedInk)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the notebook")

            ForEach(result.entries) { entry in
                NavigationLink(value: entry) {
                    SearchHitRow(entry: entry, query: query)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func summary(of result: LibrarySearch.Result) -> String {
        let game = result.notebook.gameTitle
        let count = result.entries.count
        let hits = count == 0 ? "The tale itself matches" : count == 1 ? "1 matching entry" : "\(count) matching entries"
        return game.isEmpty ? hits : "\(game) · \(hits)"
    }
}

/// One matching entry: who wrote it, when, and the words around the match.
private struct SearchHitRow: View {
    let entry: Entry
    let query: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let author = entry.author {
                MemberAvatar(member: author, size: 28)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title.isEmpty ? (entry.author?.name ?? "Narrator") : entry.title)
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.ink)
                let excerpt = LibrarySearch.excerpt(of: entry.body, matching: query)
                if !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink.opacity(0.8))
                        .lineLimit(3)
                }
                Text(entry.writtenAt, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(Theme.fadedInk)
            }
            Spacer(minLength: 0)
        }
        .parchmentCard(padding: 12)
        .accessibilityElement(children: .combine)
    }
}
