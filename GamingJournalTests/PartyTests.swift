import XCTest
import SwiftData
import UIKit
@testable import GamingJournal

final class PartyTests: XCTestCase {
    func testInitials() {
        XCTAssertEqual(PartyRoster.initials(for: "Solaire of Astora"), "SA")
        XCTAssertEqual(PartyRoster.initials(for: "lydia"), "L")
        XCTAssertEqual(PartyRoster.initials(for: "  "), "")
        XCTAssertEqual(PartyRoster.initials(for: "Commander 7 Shepard"), "CS")
    }

    func testDraftValidityAndTidying() {
        var draft = MemberDraft()
        XCTAssertFalse(draft.isValid)
        draft.name = "   "
        XCTAssertFalse(draft.isValid)
        draft.name = " Karlach "
        draft.role = " Barbarian   of Avernus "
        draft.backstory = "\nEscaped Zariel's army.\n"
        XCTAssertTrue(draft.isValid)

        let member = PartyMember(name: "x")
        draft.apply(to: member)
        XCTAssertEqual(member.name, "Karlach")
        XCTAssertEqual(member.role, "Barbarian of Avernus")
        XCTAssertEqual(member.backstory, "Escaped Zariel's army.")
    }

    func testNewMembersJoinAtTheEnd() {
        let notebook = Notebook(title: "Tav's Road")
        var draft = MemberDraft()
        draft.name = "Shadowheart"
        XCTAssertEqual(draft.makeMember(in: notebook).sortIndex, 0)

        notebook.members = [PartyMember(name: "Astarion", sortIndex: 4)]
        XCTAssertEqual(draft.makeMember(in: notebook).sortIndex, 5)
    }

    func testMoveRenumbersInNewOrder() {
        let a = PartyMember(name: "A", sortIndex: 0)
        let b = PartyMember(name: "B", sortIndex: 1)
        let c = PartyMember(name: "C", sortIndex: 2)
        PartyRoster.move([a, b, c], from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual([c, a, b].map(\.sortIndex), [0, 1, 2])
    }

    func testPortraitIsDownscaled() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1200), format: format).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1200))
        }
        let portrait = try XCTUnwrap(PartyRoster.portrait(from: try XCTUnwrap(image.pngData())))
        let decoded = try XCTUnwrap(UIImage(data: portrait))
        XCTAssertEqual(decoded.size.width * decoded.scale, PartyRoster.portraitDimension, accuracy: 1)
        XCTAssertNil(PartyRoster.portrait(from: Data("nope".utf8)))
    }
}
