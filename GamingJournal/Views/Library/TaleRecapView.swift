import SwiftUI

/// "The tale is told": the closing pages of a completed notebook.
struct TaleRecapView: View {
    @Environment(\.dismiss) private var dismiss
    let notebook: Notebook

    var body: some View {
        let recap = TaleRecap(notebook: notebook)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(recap)
                    JourneyTiles(summary: recap.summary, showsNotebookCount: false)

                    if let first = recap.firstEntry {
                        moment("How it began", systemImage: "sunrise", entry: first)
                    }
                    if !recap.turningPoints.isEmpty {
                        turningPoints(recap.turningPoints)
                    }
                    if !recap.arcs.isEmpty {
                        arcs(recap.arcs)
                    }
                    if !recap.bonds.isEmpty {
                        bonds(recap.bonds)
                    }
                    if let last = recap.lastEntry {
                        moment("How it ended", systemImage: "sunset", entry: last)
                    }
                    if !recap.hasStory {
                        Text("No entries were written in this tale, but the road was travelled all the same.")
                            .font(Theme.prose)
                            .foregroundStyle(Theme.fadedInk)
                    }
                }
                .padding()
            }
            .background {
                ZStack(alignment: .top) {
                    ParchmentBackground()
                    // Drifting embers; still under Reduce Motion.
                    EmberField(count: 14)
                        .frame(height: 260)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle("The Tale's End")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func header(_ recap: TaleRecap) -> some View {
        VStack(spacing: 10) {
            WaxSeal(systemImage: "crown.fill", size: 64, label: "Completed")
            Text("The tale is told")
                .font(Theme.title(.title))
                .foregroundStyle(Theme.ink)
            Text(notebook.title)
                .font(Theme.title(.title3))
                .foregroundStyle(Theme.ember)
            if let feeling = recap.prevailingFeeling {
                Text("A tale of \(feeling.label.lowercased())")
                    .font(Theme.prose)
                    .foregroundStyle(Theme.fadedInk)
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private func moment(_ title: String, systemImage: String, entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(Theme.heading)
                .foregroundStyle(Theme.ember)
            EntryCard(entry: entry)
        }
    }

    private func turningPoints(_ entries: [Entry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Turning points", systemImage: "seal")
                .font(Theme.heading)
                .foregroundStyle(Theme.ember)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(entries) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        WaxSeal(size: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title.isEmpty ? (entry.author?.name ?? "Narrator") : entry.title)
                                .font(.system(.body, design: .serif).weight(.semibold))
                            Text(entry.writtenAt, format: .dateTime.day().month().year())
                                .font(.caption)
                                .foregroundStyle(Theme.fadedInk)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .parchmentCard()
        }
    }

    private func arcs(_ arcs: [TaleRecap.MemberArc]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("The party", systemImage: "person.3")
                .font(Theme.heading)
                .foregroundStyle(Theme.ember)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(arcs) { arc in
                    HStack(spacing: 12) {
                        MemberAvatar(member: arc.member, size: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(arc.member.name)
                                .font(.system(.body, design: .serif).weight(.semibold))
                            Group {
                                if let journey = arc.journey {
                                    Text(journey)
                                } else {
                                    Text("^[\(arc.entryCount) entry](inflect: true)")
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(Theme.fadedInk)
                        }
                        Spacer(minLength: 4)
                        if let felt = arc.mostFelt {
                            EmotionChip(emotion: felt)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .parchmentCard()
        }
    }

    private func bonds(_ bonds: [CharacterArc.BondSummary]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Bonds that mattered", systemImage: "link")
                .font(Theme.heading)
                .foregroundStyle(Theme.ember)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(bonds) { bond in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(bond.name)
                                .font(.system(.body, design: .serif).weight(.semibold))
                            Spacer()
                            Text(Bond(targetName: bond.name, affinity: bond.affinity).affinityLabel)
                                .font(.subheadline)
                                .foregroundStyle(Theme.ember)
                        }
                        if !bond.latestNote.isEmpty {
                            Text(bond.latestNote)
                                .font(.caption)
                                .foregroundStyle(Theme.fadedInk)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .parchmentCard()
        }
    }
}
