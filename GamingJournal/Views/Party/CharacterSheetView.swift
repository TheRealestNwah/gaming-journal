import SwiftUI
import SwiftData
import Charts

/// A party member's page: who they are, how they've felt, who they trust, and what they wrote.
struct CharacterSheetView: View {
    let member: PartyMember
    @State private var isEditing = false
    @State private var isWriting = false

    var body: some View {
        if member.isDeleted || member.modelContext == nil {
            ContentUnavailableView("Removed from the party", systemImage: "person.slash")
        } else {
            sheet
        }
    }

    private var sheet: some View {
        let journal = member.journal
        let points = CharacterArc.points(for: journal)
        let mostFelt = CharacterArc.mostFelt(in: journal)
        let bonds = CharacterArc.bonds(in: journal)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if !member.backstory.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionFlourish(title: "Backstory")
                        Text(member.backstory)
                            .font(Theme.prose)
                            .lineSpacing(4)
                            .parchmentCard()
                    }
                }

                if let notebook = member.notebook {
                    Button {
                        isWriting = true
                    } label: {
                        Label("Write as \(member.name)", systemImage: "pencil.and.scribble")
                    }
                    .buttonStyle(.ember)
                    .sheet(isPresented: $isWriting) {
                        EntryEditorView(notebook: notebook, author: member)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionFlourish(title: "Emotional arc")
                    if points.count > 1 {
                        ArcChart(points: points)
                            .parchmentCard()
                    } else {
                        Text("Record feelings in at least two entries to trace \(member.name)'s arc.")
                            .font(Theme.prose)
                            .foregroundStyle(Theme.fadedInk)
                            .parchmentCard()
                    }
                    if !mostFelt.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(mostFelt) { item in
                                EmotionChip(emotion: item.emotion, intensity: min(3, max(1, item.weight)))
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Most felt")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionFlourish(title: "Bonds")
                    if bonds.isEmpty {
                        Text("No bonds recorded yet. Add them when writing an entry.")
                            .font(Theme.prose)
                            .foregroundStyle(Theme.fadedInk)
                            .parchmentCard()
                    } else {
                        VStack(spacing: 0) {
                            ForEach(bonds) { bond in
                                BondRow(bond: bond)
                                if bond.id != bonds.last?.id {
                                    Divider().overlay(Theme.rule)
                                }
                            }
                        }
                        .parchmentCard(padding: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionFlourish(title: "Their journal")
                    if journal.isEmpty {
                        Text("\(member.name) hasn't written anything yet.")
                            .font(Theme.prose)
                            .foregroundStyle(Theme.fadedInk)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(journal) { entry in
                                NavigationLink(value: entry) {
                                    EntryCard(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(ParchmentBackground())
        .navigationTitle(member.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { isEditing = true }
        }
        .sheet(isPresented: $isEditing) {
            if let notebook = member.notebook {
                MemberEditorView(notebook: notebook, member: member)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            MemberAvatar(member: member, size: 96)
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(Theme.title(.title))
                if !member.role.isEmpty {
                    Text(member.role)
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(Theme.ember)
                }
                if member.isRetired {
                    Label("Retired", systemImage: "moon.zzz")
                        .font(.caption)
                        .foregroundStyle(Theme.fadedInk)
                }
                Text("\(member.entries?.count ?? 0) entries")
                    .font(.caption)
                    .foregroundStyle(Theme.fadedInk)
            }
        }
    }
}

/// Emotional tone over time: a line from dark to bright, points coloured by the dominant feeling.
private struct ArcChart: View {
    let points: [CharacterArc.Point]

    var body: some View {
        Chart(points) { point in
            LineMark(x: .value("Date", point.date), y: .value("Tone", point.valence))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Theme.ember.opacity(0.6))
            PointMark(x: .value("Date", point.date), y: .value("Tone", point.valence))
                .foregroundStyle(point.dominant.color)
                .symbolSize(60)
                .accessibilityLabel(point.date.formatted(date: .abbreviated, time: .omitted))
                .accessibilityValue(point.dominant.label)
        }
        .chartYScale(domain: -1...1)
        .chartYAxis {
            AxisMarks(values: [-1, 0, 1]) { value in
                AxisGridLine().foregroundStyle(Theme.rule)
                AxisValueLabel {
                    switch value.as(Double.self) ?? 0 {
                    case ..<(-0.5): Text("Dark")
                    case 0.5...: Text("Bright")
                    default: Text("Torn")
                    }
                }
            }
        }
        .frame(height: 180)
    }
}

private struct BondRow: View {
    let bond: CharacterArc.BondSummary

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(bond.name)
                    .font(.system(.body, design: .serif).weight(.semibold))
                Text(Bond(targetName: bond.name, affinity: bond.affinity).affinityLabel)
                    .font(.caption)
                    .foregroundStyle(Theme.fadedInk)
                if !bond.latestNote.isEmpty {
                    Text(bond.latestNote)
                        .font(.system(.caption, design: .serif))
                        .italic()
                        .foregroundStyle(Theme.fadedInk)
                        .lineLimit(2)
                }
            }
            Spacer()
            AffinityMeter(affinity: bond.affinity)
            trendIcon
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var trendIcon: some View {
        switch bond.trend {
        case .warming:
            Image(systemName: "arrow.up.right").foregroundStyle(Theme.ember).accessibilityLabel("warming")
        case .cooling:
            Image(systemName: "arrow.down.right").foregroundStyle(Theme.crimson).accessibilityLabel("cooling")
        case .steady:
            Image(systemName: "equal").foregroundStyle(Theme.fadedInk).accessibilityLabel("steady")
        }
    }
}

/// Seven pips from −3 to +3: daggers on the cold side, hearts on the warm side.
struct AffinityMeter: View {
    let affinity: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Bond.affinityRange, id: \.self) { level in
                Image(systemName: level < 0 ? "bolt.fill" : level > 0 ? "heart.fill" : "circle.fill")
                    .font(.system(size: level == 0 ? 5 : 9))
                    .foregroundStyle(color(for: level))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Affinity")
        .accessibilityValue(Bond(targetName: "", affinity: affinity).affinityLabel)
    }

    private func color(for level: Int) -> Color {
        let lit = (affinity < 0 && level < 0 && level >= affinity) || (affinity > 0 && level > 0 && level <= affinity)
        guard lit else { return Theme.rule }
        return level < 0 ? Theme.crimson : Theme.ember
    }
}
