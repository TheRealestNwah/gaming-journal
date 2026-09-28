import XCTest
import SwiftData
@testable import GamingJournal

final class JournalBackupTests: XCTestCase {
    private func sampleSession(id: UUID = UUID(), title: String = "Hades") -> JournalBackup.Session {
        JournalBackup.Session(
            id: id,
            gameTitle: title,
            platform: "PC",
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            durationMinutes: 75,
            enjoyment: 4,
            mood: "hyped",
            notes: "Beat \"Extreme Measures\",\nfinally",
            tags: ["boss", "late night"],
            isMilestone: true,
            milestoneNote: "Heat 16",
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            photos: [
                .init(id: UUID(), imageData: Data([1, 2, 3]), thumbnailData: Data([4]), sortIndex: 0,
                      createdAt: Date(timeIntervalSince1970: 1_700_000_200)),
            ]
        )
    }

    func testRoundTripPreservesEverything() throws {
        let backup = JournalBackup(exportedAt: Date(timeIntervalSince1970: 1_800_000_000), sessions: [sampleSession()])
        let data = try backup.encoded()
        let decoded = try JournalBackup.decode(data)
        XCTAssertEqual(decoded, backup)
        XCTAssertEqual(decoded.version, JournalBackup.currentVersion)
    }

    func testDecodesDatesWithoutFractionalSeconds() throws {
        let json = #"{"version":1,"exportedAt":"2026-09-28T10:00:00Z","sessions":[]}"#
        let backup = try JournalBackup.decode(Data(json.utf8))
        XCTAssertEqual(backup.exportedAt, Date(timeIntervalSince1970: 1_790_589_600))
        XCTAssertTrue(backup.sessions.isEmpty)
    }

    func testRejectsNewerVersionsAndGarbage() {
        let newer = #"{"version":99,"exportedAt":"2026-09-28T10:00:00Z","sessions":[]}"#
        XCTAssertThrowsError(try JournalBackup.decode(Data(newer.utf8))) { error in
            XCTAssertEqual(error as? JournalBackup.BackupError, .unsupportedVersion(99))
        }
        XCTAssertThrowsError(try JournalBackup.decode(Data("nope".utf8))) { error in
            XCTAssertEqual(error as? JournalBackup.BackupError, .unreadable)
        }
    }

    func testMergePlanSkipsKnownAndRepeatedIDs() {
        let known = UUID()
        let fresh = UUID()
        let backup = JournalBackup(sessions: [
            sampleSession(id: known),
            sampleSession(id: fresh, title: "Celeste"),
            sampleSession(id: fresh, title: "Celeste again"),
        ])
        let plan = backup.mergePlan(existingIDs: [known])
        XCTAssertEqual(plan.newSessions.map(\.gameTitle), ["Celeste"])
        XCTAssertEqual(plan.skippedCount, 2)
    }

    @MainActor
    func testExportThenImportIntoStoreDoesNotDuplicate() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let original = PlaySession(gameTitle: "Tunic", platform: "PC", durationMinutes: 40, mood: .relaxed, tags: ["fox"])
        original.photos = [SessionPhoto(imageData: Data([9]), thumbnailData: nil)]
        context.insert(original)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<PlaySession>())
        let data = try JournalBackup(exporting: sessions).encoded()
        let backup = try JournalBackup.decode(data)

        // Same store: everything is already there.
        let again = backup.mergePlan(existingIDs: Set(sessions.map(\.id)))
        XCTAssertTrue(again.newSessions.isEmpty)
        XCTAssertEqual(again.skippedCount, 1)

        // Fresh store: the session comes back with its photo and mood.
        let other = try Persistence.makeContainer(inMemory: true).mainContext
        for session in backup.mergePlan(existingIDs: []).newSessions {
            other.insert(session.makeSession())
        }
        try other.save()
        let restored = try XCTUnwrap(other.fetch(FetchDescriptor<PlaySession>()).first)
        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.mood, .relaxed)
        XCTAssertEqual(restored.tags, ["fox"])
        XCTAssertEqual(restored.sortedPhotos.compactMap(\.imageData), [Data([9])])
    }
}

final class SessionCSVTests: XCTestCase {
    func testEscaping() {
        XCTAssertEqual(SessionCSV.escape("plain"), "plain")
        XCTAssertEqual(SessionCSV.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(SessionCSV.escape("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(SessionCSV.escape("line\nbreak"), "\"line\nbreak\"")
        XCTAssertEqual(SessionCSV.escape(" padded"), "\" padded\"")
        XCTAssertEqual(SessionCSV.escape(""), "")
    }

    func testExportRows() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let session = JournalBackup.Session(
            id: id, gameTitle: "Hades, II", platform: "PC",
            startDate: Date(timeIntervalSince1970: 0), durationMinutes: 90, enjoyment: nil, mood: nil,
            notes: "ok", tags: ["a", "b"], isMilestone: false, milestoneNote: "",
            createdAt: Date(timeIntervalSince1970: 0), photos: []
        )
        let lines = SessionCSV.export([session]).components(separatedBy: "\r\n")
        XCTAssertEqual(lines[0], SessionCSV.header.joined(separator: ","))
        XCTAssertEqual(lines[1], "\(id.uuidString),\"Hades, II\",PC,1970-01-01T00:00:00Z,90,,,no,,a; b,ok")
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[2], "")
    }
}
