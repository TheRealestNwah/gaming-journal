import SwiftUI
import SwiftData
import Charts

/// Totals, charts, streaks and a heatmap of play time.
struct StatsView: View {
    @Query private var sessions: [PlaySession]
    @State private var range: StatsRange = .month

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No stats yet",
                        systemImage: "chart.bar",
                        description: Text("Charts appear once you log a few sessions.")
                    )
                } else {
                    content
                }
            }
            .navigationTitle("Stats")
        }
        .sessionOverlays()
    }

    private var content: some View {
        let calculator = StatsCalculator()
        let all = sessions.map(StatsRecord.init(session:))
        let inRange = calculator.records(all, in: range)
        let summary = calculator.summary(of: inRange)
        let streaks = calculator.streaks(all)

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Range", selection: $range) {
                    ForEach(StatsRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                SummaryTiles(summary: summary, streaks: streaks)

                StatsCard(title: "Time played") {
                    TimeChart(buckets: calculator.timeBuckets(all, range: range), range: range)
                }

                let games = calculator.topGames(inRange)
                if !games.isEmpty {
                    StatsCard(title: "Top games") {
                        ShareBars(shares: games)
                    }
                }

                let platforms = calculator.platformShares(inRange)
                if !platforms.isEmpty {
                    StatsCard(title: "Platforms") {
                        ShareBars(shares: platforms)
                    }
                }

                let trend = calculator.enjoymentTrend(all, range: range)
                if trend.count > 1 {
                    StatsCard(title: "Enjoyment") {
                        EnjoymentChart(points: trend, range: range)
                    }
                }

                StatsCard(title: "Days played") {
                    HeatmapGrid(days: calculator.heatmap(all), calendar: calculator.calendar)
                }
            }
            .padding()
        }
        .background(ParchmentBackground())
    }
}

private struct StatsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.heading)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.vellum, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.rule, lineWidth: 1))
    }
}

private struct SummaryTiles: View {
    let summary: StatsCalculator.Summary
    let streaks: StatsCalculator.Streaks

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            tile("Played", PlaytimeFormatter.string(fromMinutes: summary.totalMinutes), systemImage: "clock")
            tile("Sessions", "\(summary.sessionCount)", systemImage: "list.bullet")
            tile("Games", "\(summary.gamesPlayed)", systemImage: "square.stack")
            tile("Avg. session", PlaytimeFormatter.string(fromMinutes: summary.averageSessionMinutes), systemImage: "timer")
            tile("Current streak", days(streaks.current), systemImage: "flame")
            tile("Longest streak", days(streaks.longest), systemImage: "trophy")
        }
    }

    private func days(_ count: Int) -> String {
        "\(count) day\(count == 1 ? "" : "s")"
    }

    private func tile(_ label: String, _ value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.vellum, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.rule, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

private struct TimeChart: View {
    let buckets: [StatsCalculator.Bucket]
    let range: StatsRange

    var body: some View {
        Chart(buckets) { bucket in
            BarMark(
                x: .value("Period", bucket.start, unit: range.bucket),
                y: .value("Hours", bucket.hours)
            )
            .foregroundStyle(Color.accentColor.gradient)
            .accessibilityLabel(bucket.start.formatted(date: .abbreviated, time: .omitted))
            .accessibilityValue(PlaytimeFormatter.string(fromMinutes: bucket.minutes))
        }
        .chartYAxisLabel("Hours")
        .frame(height: 200)
    }
}

private struct ShareBars: View {
    let shares: [StatsCalculator.Share]

    var body: some View {
        Chart(shares) { share in
            BarMark(
                x: .value("Hours", share.hours),
                y: .value("Name", share.name)
            )
            .foregroundStyle(by: .value("Name", share.name))
            .annotation(position: .trailing, alignment: .leading) {
                Text(PlaytimeFormatter.string(fromMinutes: share.minutes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(share.name)
            .accessibilityValue(PlaytimeFormatter.string(fromMinutes: share.minutes))
        }
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .frame(height: CGFloat(shares.count) * 36 + 8)
    }
}

private struct EnjoymentChart: View {
    let points: [StatsCalculator.TrendPoint]
    let range: StatsRange

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Period", point.start, unit: range.bucket),
                y: .value("Enjoyment", point.average)
            )
            .interpolationMethod(.catmullRom)
            PointMark(
                x: .value("Period", point.start, unit: range.bucket),
                y: .value("Enjoyment", point.average)
            )
        }
        .chartYScale(domain: 1...5)
        .chartYAxis {
            AxisMarks(values: [1, 2, 3, 4, 5])
        }
        .frame(height: 160)
    }
}

/// GitHub-style grid: one column per week, one row per weekday, shaded by minutes played.
private struct HeatmapGrid: View {
    let days: [StatsCalculator.Bucket]
    let calendar: Calendar

    private var weeks: [[StatsCalculator.Bucket]] {
        stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    private var maxMinutes: Int {
        max(1, days.map(\.minutes).max() ?? 1)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 3) {
            ForEach(weeks, id: \.first?.start) { week in
                VStack(spacing: 3) {
                    ForEach(week) { day in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(for: day.minutes))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Played on \(days.filter { $0.minutes > 0 }.count) of the last \(days.count) days")
    }

    private func color(for minutes: Int) -> Color {
        guard minutes > 0 else { return Color.secondary.opacity(0.15) }
        let level = Double(minutes) / Double(maxMinutes)
        return Color.accentColor.opacity(0.3 + 0.7 * level)
    }
}
