import SwiftUI

/// Editor section for the bonds an entry records: how the writer feels about others right now.
struct BondsSection: View {
    @Binding var bonds: [Bond]
    /// Party members the writer can feel something about (everyone except the writer).
    let others: [PartyMember]
    @State private var isNamingSomeoneElse = false
    @State private var newName = ""

    private var availableMembers: [PartyMember] {
        others.filter { member in !bonds.contains { $0.targetMemberID == member.id } }
    }

    var body: some View {
        Section {
            ForEach($bonds) { $bond in
                BondEditorRow(bond: $bond) {
                    bonds.removeAll { $0.id == bond.id }
                }
            }
            Menu {
                ForEach(availableMembers) { member in
                    Button(member.name) {
                        bonds.append(Bond(targetMemberID: member.id, targetName: member.name, affinity: 0))
                    }
                }
                Button("Someone else…", systemImage: "person.badge.plus") {
                    newName = ""
                    isNamingSomeoneElse = true
                }
            } label: {
                Label("Add a bond", systemImage: "heart.text.square")
            }
        } header: {
            Text("Bonds")
        } footer: {
            Text("How does the writer feel about their companions and the people they meet?")
        }
        .alert("Who is it?", isPresented: $isNamingSomeoneElse) {
            TextField("Name", text: $newName)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                bonds.append(Bond(targetName: name, affinity: 0))
            }
        }
    }
}

private struct BondEditorRow: View {
    @Binding var bond: Bond
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(bond.targetName)
                    .font(.system(.body, design: .serif).weight(.semibold))
                Spacer()
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.fadedInk)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove bond with \(bond.targetName)")
            }
            Stepper(value: $bond.affinity, in: Bond.affinityRange) {
                HStack(spacing: 8) {
                    AffinityMeter(affinity: bond.affinity)
                    Text(bond.affinityLabel)
                        .font(.subheadline)
                        .foregroundStyle(bond.affinity < 0 ? Theme.crimson : bond.affinity > 0 ? Theme.ember : Theme.fadedInk)
                }
            }
            .accessibilityValue(bond.affinityLabel)
            TextField("Why? (optional)", text: $bond.note)
                .font(.system(.subheadline, design: .serif))
        }
        .padding(.vertical, 4)
    }
}
