import WidgetKit
import SwiftUI

@main
struct GamingJournalWidgetBundle: WidgetBundle {
    var body: some Widget {
        LatestEntryWidget()
        WriteAsWidget()
        if #available(iOS 18.0, *) {
            WriteControl()
        }
    }
}

// MARK: Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : Snapshot.load()))
    }

    /// The app reloads the timeline whenever the latest entry changes.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        completion(Timeline(entries: [SnapshotEntry(date: .now, snapshot: Snapshot.load())], policy: .never))
    }
}

// MARK: Latest entry

struct LatestEntryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LatestEntry", provider: SnapshotProvider()) { entry in
            LatestEntryView(entry: entry)
                .containerBackground(for: .widget) { Page.background }
                .widgetURL(entry.snapshot?.latestEntry.map { Snapshot.writeURL(for: $0.journalID) } ?? Snapshot.writeURL)
        }
        .configurationDisplayName("From the Journal")
        .description("The latest entry. Tap to write the next one.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LatestEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        if let latest = entry.snapshot?.latestEntry {
            VStack(alignment: .leading, spacing: 5) {
                Text(latest.heading)
                    .font(Page.book(13, relativeTo: .caption))
                    .fontWeight(.semibold)
                    .foregroundStyle(Page.rubric)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(latest.excerpt)
                    .font(Page.book(family == .systemSmall ? 14 : 15))
                    .foregroundStyle(Page.ink)
                    .lineLimit(family == .systemSmall ? 5 : 4)
                Spacer(minLength: 0)
                Text("— \(latest.characterName)")
                    .font(Page.bookItalic(12, relativeTo: .caption))
                    .foregroundStyle(Page.faded)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "book.closed")
                    .font(.title)
                    .foregroundStyle(Page.rubric)
                Text("Begin a journal")
                    .font(Page.book(14))
                    .foregroundStyle(Page.ink)
            }
        }
    }
}
