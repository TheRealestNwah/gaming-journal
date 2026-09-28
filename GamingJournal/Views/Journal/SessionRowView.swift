import SwiftUI

/// One session in the timeline: title, time, platform, rating and the start of the notes.
struct SessionRowView: View {
    let session: PlaySession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                if session.isMilestone {
                    WaxSeal(size: 18, label: "Milestone")
                }
                Text(session.gameTitle).font(Theme.heading)
                Spacer()
                Text(session.formattedDuration)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Text(session.startDate, format: .dateTime.hour().minute())
                if !session.platform.isEmpty {
                    Text("·")
                    Text(session.platform)
                }
                if let mood = session.mood {
                    Text("·")
                    Text(mood.emoji).accessibilityLabel(mood.label)
                }
                if let count = session.photos?.count, count > 0 {
                    Text("·")
                    Label("\(count)", systemImage: "photo")
                        .labelStyle(.titleAndIcon)
                        .accessibilityLabel("\(count) photo\(count == 1 ? "" : "s")")
                }
                if let enjoyment = session.enjoyment {
                    Text("·")
                    Label("\(enjoyment)", systemImage: "star.fill")
                        .labelStyle(.titleAndIcon)
                        .accessibilityLabel("\(enjoyment) of 5 stars")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            if session.isMilestone && !session.milestoneNote.isEmpty {
                Text(session.milestoneNote)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ember)
            }
            if !session.notes.isEmpty {
                Text(session.notes)
                    .font(.system(.subheadline, design: .serif))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
