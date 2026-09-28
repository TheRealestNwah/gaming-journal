import SwiftUI
import SwiftData
import PhotosUI

/// Round portrait, or initials on the member's sigil colour, ringed in gold.
struct MemberAvatar: View {
    let name: String
    let sigil: Sigil
    let portraitData: Data?
    var size: CGFloat = 56

    init(member: PartyMember, size: CGFloat = 56) {
        name = member.name
        sigil = member.sigil
        portraitData = member.portraitData
        self.size = size
    }

    init(name: String, sigil: Sigil, portraitData: Data?, size: CGFloat = 56) {
        self.name = name
        self.sigil = sigil
        self.portraitData = portraitData
        self.size = size
    }

    var body: some View {
        Group {
            if let portraitData, let image = UIImage(data: portraitData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: sigil.hex), Color(hex: sigil.hex).opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text(PartyRoster.initials(for: name))
                        .font(.system(size: size * 0.36, weight: .bold, design: .serif))
                        .foregroundStyle(Color(hex: 0xF7ECD9))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Theme.gold, lineWidth: max(1.5, size * 0.04)))
        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
        .accessibilityHidden(true)
    }
}

/// The party strip in a notebook: avatars, an add button and a way to rearrange.
struct PartySection: View {
    let notebook: Notebook
    let onSelect: (PartyMember) -> Void
    @State private var isAdding = false
    @State private var isArranging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionFlourish(title: "The Party")
                if (notebook.members?.count ?? 0) > 1 {
                    Button("Arrange") { isArranging = true }
                        .font(.subheadline)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(notebook.party) { member in
                        Button { onSelect(member) } label: {
                            VStack(spacing: 6) {
                                MemberAvatar(member: member, size: 64)
                                    .opacity(member.isRetired ? 0.5 : 1)
                                Text(member.name)
                                    .font(.system(.caption, design: .serif).weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                if !member.role.isEmpty {
                                    Text(member.role)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.fadedInk)
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 84)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            [member.name, member.role, member.isRetired ? "Retired" : ""]
                                .filter { !$0.isEmpty }
                                .joined(separator: ", ")
                        )
                    }
                    Button { isAdding = true } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .frame(width: 64, height: 64)
                                .background(Circle().strokeBorder(Theme.ember, style: StrokeStyle(lineWidth: 1.5, dash: [4])))
                                .foregroundStyle(Theme.ember)
                            Text(notebook.party.isEmpty ? "Add a hero" : "Recruit")
                                .font(.caption)
                                .foregroundStyle(Theme.ember)
                        }
                        .frame(width: 84)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add a party member")
                }
                .padding(.vertical, 4)
            }
        }
        .sheet(isPresented: $isAdding) {
            MemberEditorView(notebook: notebook)
        }
        .sheet(isPresented: $isArranging) {
            ArrangePartyView(notebook: notebook)
        }
    }
}

/// Create or edit a party member.
struct MemberEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let notebook: Notebook
    private let member: PartyMember?
    @State private var draft: MemberDraft
    @State private var pickerItem: PhotosPickerItem?
    @State private var isConfirmingRemoval = false

    init(notebook: Notebook, member: PartyMember? = nil) {
        self.notebook = notebook
        self.member = member
        _draft = State(initialValue: member.map(MemberDraft.init(member:)) ?? MemberDraft())
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        HStack(spacing: 16) {
                            MemberAvatar(name: draft.name, sigil: draft.sigil, portraitData: draft.portraitData, size: 72)
                            VStack(alignment: .leading, spacing: 8) {
                                PhotosPicker(selection: $pickerItem, matching: .images) {
                                    Label(draft.portraitData == nil ? "Add portrait" : "Change portrait", systemImage: "photo")
                                }
                                if draft.portraitData != nil {
                                    Button("Remove portrait", role: .destructive) { draft.portraitData = nil }
                                        .font(.subheadline)
                                }
                            }
                        }
                        TextField("Name", text: $draft.name)
                            .font(Theme.heading)
                            .textInputAutocapitalization(.words)
                        TextField("Role or class, e.g. Ranger", text: $draft.role)
                            .textInputAutocapitalization(.words)
                    }

                    Section("Sigil") {
                        SigilPicker(selection: $draft.sigil)
                    }

                    Section("Backstory") {
                        TextField("Where do they come from? What drives them?", text: $draft.backstory, axis: .vertical)
                            .font(Theme.prose)
                            .lineLimit(4...12)
                    }

                    if member != nil {
                        Section {
                            Toggle("Retired from the party", isOn: $draft.isRetired)
                        } footer: {
                            Text("For fallen or departed companions. Their entries stay in the chronicle.")
                        }
                        Section {
                            Button("Remove from Notebook", role: .destructive) { isConfirmingRemoval = true }
                        }
                    }
                }
                .listRowBackground(Theme.vellum)
            }
            .parchmentBackground()
            .navigationTitle(member == nil ? "New Party Member" : "Edit \(member?.name ?? "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.isValid)
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let portrait = await Task.detached(operation: { PartyRoster.portrait(from: data) }).value {
                        draft.portraitData = portrait
                    }
                    pickerItem = nil
                }
            }
            .confirmationDialog("Remove \(member?.name ?? "")?", isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
                Button("Remove", role: .destructive, action: remove)
            } message: {
                Text("Their entries stay in the chronicle, unsigned. To keep them in the party record, mark them retired instead.")
            }
        }
    }

    private func save() {
        if let member {
            draft.apply(to: member)
        } else {
            let newMember = draft.makeMember(in: notebook)
            context.insert(newMember)
            newMember.notebook = notebook
        }
        notebook.touch()
        try? context.save()
        dismiss()
    }

    private func remove() {
        guard let member else { return }
        context.delete(member)
        notebook.touch()
        try? context.save()
        dismiss()
    }
}

/// Row of sigil colours.
private struct SigilPicker: View {
    @Binding var selection: Sigil

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Sigil.allCases) { sigil in
                Button {
                    selection = sigil
                } label: {
                    Circle()
                        .fill(Color(hex: sigil.hex))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle().strokeBorder(Theme.ink, lineWidth: selection == sigil ? 3 : 0)
                        )
                        .overlay {
                            if selection == sigil {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(sigil.label)
                .accessibilityAddTraits(selection == sigil ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Drag to reorder the party.
private struct ArrangePartyView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let notebook: Notebook

    var body: some View {
        NavigationStack {
            List {
                ForEach(notebook.party) { member in
                    HStack(spacing: 12) {
                        MemberAvatar(member: member, size: 36)
                        VStack(alignment: .leading) {
                            Text(member.name).font(Theme.heading)
                            if !member.role.isEmpty {
                                Text(member.role).font(.caption).foregroundStyle(Theme.fadedInk)
                            }
                        }
                    }
                    .listRowBackground(Theme.vellum)
                }
                .onMove { source, destination in
                    PartyRoster.move(notebook.party, from: source, to: destination)
                    try? context.save()
                }
            }
            .environment(\.editMode, .constant(.active))
            .parchmentBackground()
            .navigationTitle("Arrange the Party")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}
