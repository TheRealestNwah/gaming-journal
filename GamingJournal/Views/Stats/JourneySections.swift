import SwiftUI
import Charts

/// Headline numbers for the journey: days, entries, words, hours, turning points.
struct JourneyTiles: View {
    let summary: JourneyCalculator.Summary
    let showsNotebookCount: Bool

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if showsNotebookCount {
                tile("Tales", "\(summary.notebookCount)", detail: "\(summary.completedCount) completed", systemImage: "books.vertical")
            }
            tile("Days on the road", "\(summary.daysOnJourney)", systemImage: "map")
            tile("Entries", "\(summary.entryCount)", systemImage: "book")
            tile("Words written", summary.wordCount.formatted(), systemImage: "pencil.and.scribble")
            tile("Hours played", PlaytimeFormatter.string(fromMinutes: summary.minutesPlayed), systemImage: "hourglass")
            tile("Turning points", "\(summary.turningPoints)", systemImage: "seal")
        }
    }

    private func tile(_ label: String, _ value: String, detail: String? = nil, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(Theme.fadedInk)
            Text(value)
                .font(.system(.title2, design: .serif).weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.ink)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Theme.fadedInk)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.vellum, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.rule, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Bars for each emotion family, coloured like the arc chart.
struct EmotionGroupChart: View {
    let shares: [JourneyCalculator.GroupShare]

    var body: some View {
        Chart(shares) { share in
            BarMark(x: .value("Weight", share.weight), y: .value("Feeling", share.group.label))
                .foregroundStyle(share.group.color)
                .accessibilityLabel(share.group.label)
                .accessibilityValue("\(share.weight)")
        }
        .chartXAxis(.hidden)
        .frame(height: CGFloat(shares.count) * 34 + 8)
    }
}

/// Entries written each month.
struct EntriesPerMonthChart: View {
    let months: [JourneyCalculator.MonthCount]

    var body: some View {
        Chart(months) { month in
            BarMark(x: .value("Month", month.month, unit: .month), y: .value("Entries", month.entries))
                .foregroundStyle(Theme.ember.gradient)
                .accessibilityLabel(month.month.formatted(.dateTime.month(.wide).year()))
                .accessibilityValue("\(month.entries) entries")
        }
        .frame(height: 160)
    }
}
