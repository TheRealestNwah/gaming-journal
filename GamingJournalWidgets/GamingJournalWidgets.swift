import WidgetKit
import SwiftUI

@main
struct GamingJournalWidgetBundle: WidgetBundle {
    var body: some Widget {
        LatestEntryWidget()
        NowPlayingWidget()
        WeekWidget()
        StartSessionWidget()
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

    /// The app reloads timelines when data changes; the hourly refresh rolls the week over.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: Snapshot.load())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: Latest entry

struct LatestEntryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LatestEntry", provider: SnapshotProvider()) { entry in
            LatestEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(red: 0.96, green: 0.91, blue: 0.85), Color(red: 0.93, green: 0.85, blue: 0.74)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .widgetURL(entry.snapshot?.latestEntry.map { Snapshot.writeURL(for: $0.notebookID) } ?? Snapshot.writeURL)
        }
        .configurationDisplayName("From the Journal")
        .description("The latest entry. Tap to write the next one.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LatestEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private let ink = Color(red: 0.17, green: 0.11, blue: 0.08)
    private let faded = Color(red: 0.42, green: 0.33, blue: 0.26)
    private let ember = Color(red: 0.66, green: 0.27, blue: 0.10)

    var body: some View {
        if let latest = entry.snapshot?.latestEntry {
            VStack(alignment: .leading, spacing: 6) {
                Label(latest.notebookTitle, systemImage: "book.closed.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ember)
                    .lineLimit(1)
                if !latest.title.isEmpty {
                    Text(latest.title)
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(ink)
                        .lineLimit(2)
                }
                Text("“\(latest.excerpt)”")
                    .font(.system(family == .systemSmall ? .caption : .subheadline, design: .serif))
                    .italic()
                    .foregroundStyle(ink.opacity(0.85))
                    .lineLimit(family == .systemSmall ? 4 : 3)
                Spacer(minLength: 0)
                Text("— \(latest.author)")
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(faded)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "pencil.and.scribble")
                    .font(.title)
                    .foregroundStyle(ember)
                Text("Begin your tale")
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(ink)
            }
        }
    }
}

// MARK: Now playing / last session

struct NowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NowPlaying", provider: SnapshotProvider()) { entry in
            NowPlayingView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Now Playing")
        .description("The running timer, or your last session.")
        .supportedFamilies([.systemSmall])
    }
}

struct NowPlayingView: View {
    let entry: SnapshotEntry

    var body: some View {
        if let timer = entry.snapshot?.timer {
            VStack(alignment: .leading, spacing: 6) {
                Label(timer.isPaused ? "Paused" : "Playing", systemImage: timer.isPaused ? "pause.fill" : "gamecontroller.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(timer.isPaused ? Color.secondary : Color.accentColor)
                Text(timer.title.isEmpty ? "Session" : timer.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if timer.isPaused {
                    Text(Format.clock(timer.elapsed(at: entry.date)))
                        .font(.title2.monospacedDigit().weight(.semibold))
                } else {
                    Text(timer.clockStart(now: entry.date), style: .timer)
                        .font(.title2.monospacedDigit().weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else if let last = entry.snapshot?.lastSession {
            VStack(alignment: .leading, spacing: 6) {
                Label("Last played", systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(last.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text(Format.minutes(last.minutes))
                    .font(.title2.weight(.semibold))
                Text(last.start, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "gamecontroller")
                    .font(.title)
                Text("No sessions yet")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: This week

struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ThisWeek", provider: SnapshotProvider()) { entry in
            WeekView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("This Week")
        .description("Hours played this week and your top games.")
        .supportedFamilies([.systemMedium])
    }
}

struct WeekView: View {
    let entry: SnapshotEntry

    var body: some View {
        let snapshot = entry.snapshot
        let total = snapshot?.weekMinutes(now: entry.date) ?? 0
        let games = snapshot?.topGames(now: entry.date) ?? []
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("This week")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(Format.minutes(total))
                    .font(.largeTitle.weight(.bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 8) {
                if games.isEmpty {
                    Text("Nothing played yet this week.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(games, id: \.self) { game in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(game.title)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(Format.minutes(game.minutes))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: Double(game.minutes), total: Double(max(total, 1)))
                                .tint(.accentColor)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: Start session

struct StartSessionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StartSession", provider: SnapshotProvider()) { entry in
            StartSessionView(entry: entry)
                .containerBackground(Color.accentColor.gradient, for: .widget)
                .widgetURL(Snapshot.startTimerURL)
        }
        .configurationDisplayName("Start Session")
        .description("Start the play timer in one tap.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct StartSessionView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: entry.snapshot?.timer == nil ? "play.fill" : "timer")
                    .font(.title2)
            }
            .widgetAccentable()
        } else {
            VStack(spacing: 8) {
                Image(systemName: entry.snapshot?.timer == nil ? "play.circle.fill" : "timer")
                    .font(.system(size: 44))
                Text(entry.snapshot?.timer == nil ? "Start Session" : "Timer running")
                    .font(.headline)
            }
            .foregroundStyle(.white)
        }
    }
}
