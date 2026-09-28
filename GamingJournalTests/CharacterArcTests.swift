import XCTest
@testable import GamingJournal

final class CharacterArcTests: XCTestCase {
    private func day(_ n: Double) -> Date {
        Date(timeIntervalSince1970: n * 86_400)
    }

    func testPointsWeighValenceByIntensityAndSkipUnfeltEntries() throws {
        let entries = [
            Entry(writtenAt: day(3), emotions: [FeltEmotion(.grieving, intensity: 3)]),
            Entry(writtenAt: day(1), emotions: [FeltEmotion(.joyful, intensity: 1), FeltEmotion(.afraid, intensity: 3)]),
            Entry(writtenAt: day(2)),
        ]
        let points = CharacterArc.points(for: entries)
        XCTAssertEqual(points.map(\.date), [day(1), day(3)])

        // (warmth +1 × 1 + shadow −1 × 3) / 4 = −0.5, dominated by shadow.
        XCTAssertEqual(points[0].valence, -0.5, accuracy: 0.0001)
        XCTAssertEqual(points[0].dominant, .shadow)
        XCTAssertEqual(points[1].valence, -1, accuracy: 0.0001)
    }

    func testDominantTieGoesToFirstListedGroup() {
        let points = CharacterArc.points(for: [
            Entry(emotions: [FeltEmotion(.angry, intensity: 2), FeltEmotion(.hopeful, intensity: 2)]),
        ])
        XCTAssertEqual(points.first?.dominant, .resolve)
    }

    func testMostFeltSumsIntensity() {
        let entries = [
            Entry(emotions: [FeltEmotion(.determined, intensity: 2), FeltEmotion(.weary, intensity: 1)]),
            Entry(emotions: [FeltEmotion(.determined, intensity: 3), FeltEmotion(.lost, intensity: 3)]),
        ]
        let felt = CharacterArc.mostFelt(in: entries, limit: 2)
        XCTAssertEqual(felt.map(\.emotion), [.determined, .lost])
        XCTAssertEqual(felt.map(\.weight), [5, 3])
    }

    func testBondsTrackHistoryTrendAndSortByStrength() {
        let lydiaID = UUID()
        let entries = [
            Entry(writtenAt: day(1), bonds: [Bond(targetMemberID: lydiaID, targetName: "Lydia", affinity: 1)]),
            Entry(writtenAt: day(3), bonds: [
                Bond(targetMemberID: lydiaID, targetName: "Lydia", affinity: 3, note: "Took an arrow for me"),
                Bond(targetName: "nazeem", affinity: -1),
            ]),
            Entry(writtenAt: day(2), bonds: [Bond(targetName: "Nazeem", affinity: 0, note: "Harmless?")]),
        ]
        let bonds = CharacterArc.bonds(in: entries)
        XCTAssertEqual(bonds.map(\.name), ["Lydia", "nazeem"])

        let lydia = bonds[0]
        XCTAssertEqual(lydia.history.map(\.affinity), [1, 3])
        XCTAssertEqual(lydia.trend, .warming)
        XCTAssertEqual(lydia.latestNote, "Took an arrow for me")

        let nazeem = bonds[1]
        XCTAssertEqual(nazeem.history.map(\.affinity), [0, -1])
        XCTAssertEqual(nazeem.trend, .cooling)
        XCTAssertEqual(nazeem.latestNote, "Harmless?")
    }

    func testSingleRecordIsSteady() {
        let bonds = CharacterArc.bonds(in: [Entry(bonds: [Bond(targetName: "Serana", affinity: 2)])])
        XCTAssertEqual(bonds.first?.trend, .steady)
        XCTAssertEqual(bonds.first?.affinity, 2)
    }
}
