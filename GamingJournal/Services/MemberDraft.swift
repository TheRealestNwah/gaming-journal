import Foundation
import SwiftUI
import UIKit

/// Editable copy of a party member, so the editor can be cancelled without touching the model.
struct MemberDraft: Equatable {
    var name = ""
    var role = ""
    var backstory = ""
    var sigil: Sigil = .ember
    var portraitData: Data?
    var isRetired = false

    init() {}

    init(member: PartyMember) {
        name = member.name
        role = member.role
        backstory = member.backstory
        sigil = member.sigil
        portraitData = member.portraitData
        isRetired = member.isRetired
    }

    private static func tidy(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    var isValid: Bool {
        !Self.tidy(name).isEmpty
    }

    /// Initials for an avatar without a portrait: "Solaire of Astora" → "SA".
    var initials: String {
        PartyRoster.initials(for: name)
    }

    /// Adds a new member at the end of the notebook's party.
    func makeMember(in notebook: Notebook, now: Date = .now) -> PartyMember {
        let member = PartyMember(name: Self.tidy(name), createdAt: now)
        member.sortIndex = (notebook.members ?? []).map(\.sortIndex).max().map { $0 + 1 } ?? 0
        apply(to: member)
        return member
    }

    func apply(to member: PartyMember) {
        member.name = Self.tidy(name)
        member.role = Self.tidy(role)
        member.backstory = backstory.trimmingCharacters(in: .whitespacesAndNewlines)
        member.sigil = sigil
        member.portraitData = portraitData
        member.isRetired = isRetired
    }
}

enum PartyRoster {
    static let portraitDimension: CGFloat = 600

    static func initials(for name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace).filter { $0.first?.isLetter == true }
        let letters = words.count > 1 ? [words.first, words.last] : [words.first]
        return letters.compactMap { $0?.first.map(String.init) }.joined().uppercased()
    }

    /// Moves members like `List.onMove` and renumbers everyone 0, 1, 2… in the new order.
    static func move(_ members: [PartyMember], from source: IndexSet, to destination: Int) {
        var ordered = members
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, member) in ordered.enumerated() {
            member.sortIndex = index
        }
    }

    /// Shrinks a picked image to a portrait-sized JPEG.
    static func portrait(from data: Data) -> Data? {
        UIImage(data: data).flatMap { PhotoProcessor.jpeg($0, maxDimension: portraitDimension, quality: 0.85) }
    }
}
