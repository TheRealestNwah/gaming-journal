import XCTest
import SwiftData
import UIKit
@testable import GamingJournal

final class PhotoProcessorTests: XCTestCase {
    func testFittedSizeKeepsAspectAndNeverUpscales() {
        XCTAssertEqual(PhotoProcessor.fittedSize(for: CGSize(width: 4000, height: 3000), maxDimension: 2000),
                       CGSize(width: 2000, height: 1500))
        XCTAssertEqual(PhotoProcessor.fittedSize(for: CGSize(width: 1000, height: 4000), maxDimension: 400),
                       CGSize(width: 100, height: 400))
        XCTAssertEqual(PhotoProcessor.fittedSize(for: CGSize(width: 300, height: 200), maxDimension: 2048),
                       CGSize(width: 300, height: 200))
        XCTAssertEqual(PhotoProcessor.fittedSize(for: CGSize(width: 10_000, height: 1), maxDimension: 100),
                       CGSize(width: 100, height: 1))
        XCTAssertEqual(PhotoProcessor.fittedSize(for: .zero, maxDimension: 100), .zero)
    }

    func testProcessProducesDownscaledJPEGs() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1500), format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3000, height: 1500))
        }
        let pngData = try XCTUnwrap(source.pngData())

        let processed = try XCTUnwrap(PhotoProcessor.process(pngData))
        let full = try XCTUnwrap(UIImage(data: processed.imageData))
        let thumbnail = try XCTUnwrap(UIImage(data: processed.thumbnailData))
        XCTAssertEqual(full.size.width * full.scale, 2048, accuracy: 1)
        XCTAssertEqual(full.size.height * full.scale, 1024, accuracy: 1)
        XCTAssertEqual(thumbnail.size.width * thumbnail.scale, 320, accuracy: 1)
        XCTAssertLessThan(processed.thumbnailData.count, processed.imageData.count)
    }

    func testProcessRejectsNonImageData() {
        XCTAssertNil(PhotoProcessor.process(Data("not an image".utf8)))
    }
}

final class SessionPhotoDraftTests: XCTestCase {
    private func photo(_ byte: UInt8) -> DraftPhoto {
        DraftPhoto(imageData: Data([byte]), thumbnailData: Data([byte, byte]))
    }

    @MainActor
    func testApplyAddsRemovesAndReordersPhotos() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let index = GameTitleIndex(entries: [])

        var draft = SessionDraft()
        draft.gameTitle = "Elden Ring"
        let a = photo(1), b = photo(2), c = photo(3)
        draft.photos = [a, b, c]
        let session = draft.makeSession(index: index)
        context.insert(session)
        try context.save()
        XCTAssertEqual(session.sortedPhotos.map(\.id), [a.id, b.id, c.id])

        var edit = SessionDraft(session: session)
        XCTAssertEqual(edit.photos, [a, b, c])
        let d = photo(4)
        edit.photos = [c, a, d]
        edit.apply(to: session, index: index)
        try context.save()

        XCTAssertEqual(session.sortedPhotos.map(\.id), [c.id, a.id, d.id])
        XCTAssertEqual(session.sortedPhotos.map(\.sortIndex), [0, 1, 2])
        let stored = try context.fetch(FetchDescriptor<SessionPhoto>())
        XCTAssertEqual(Set(stored.map(\.id)), [a.id, c.id, d.id])
    }

    @MainActor
    func testDeletingSessionCascadesAndUndoRestoresPhotos() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        var draft = SessionDraft()
        draft.gameTitle = "Hades"
        draft.photos = [photo(7), photo(8)]
        let session = draft.makeSession(index: GameTitleIndex(entries: []))
        context.insert(session)
        try context.save()

        let center = UndoCenter()
        context.deleteSessions([session], undo: center)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SessionPhoto>()), 0)

        center.undo()
        let restored = try XCTUnwrap(context.fetch(FetchDescriptor<PlaySession>()).first)
        XCTAssertEqual(restored.sortedPhotos.compactMap(\.imageData), [Data([7]), Data([8])])
    }
}

final class StoreOnDiskTests: XCTestCase {
    func testStoreFileReopensWithSessionsAndNotebooks() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("journal.store")

        do {
            let container = try Persistence.makeContainer(url: url)
            let context = ModelContext(container)
            let notebook = Notebook(title: "The Long Road", gameTitle: "Outer Wilds")
            let session = PlaySession(gameTitle: "Outer Wilds", durationMinutes: 90, tags: ["space"])
            context.insert(notebook)
            context.insert(session)
            session.notebook = notebook
            try context.save()
        }

        let reopened = try Persistence.makeContainer(url: url)
        let context = ModelContext(reopened)
        let sessions = try context.fetch(FetchDescriptor<PlaySession>())
        XCTAssertEqual(sessions.map(\.gameTitle), ["Outer Wilds"])
        XCTAssertEqual(sessions.first?.notebook?.title, "The Long Road")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Notebook>()).first?.sessions?.count, 1)
    }
}
