#if os(macOS)
import AppKit
import XCTest
@testable import GamingJournal

final class MacPhotoTests: XCTestCase {
    func testNativePhotoProcessingProducesBoundedJPEGs() throws {
        let image = NSImage(size: CGSize(width: 3000, height: 1500), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        let processed = try XCTUnwrap(PhotoProcessor.process(image))
        let full = try XCTUnwrap(NSBitmapImageRep(data: processed.imageData))
        let thumbnail = try XCTUnwrap(NSBitmapImageRep(data: processed.thumbnailData))
        XCTAssertEqual(full.pixelsWide, 2048)
        XCTAssertEqual(full.pixelsHigh, 1024)
        XCTAssertEqual(thumbnail.pixelsWide, 320)
        XCTAssertEqual(thumbnail.pixelsHigh, 160)
        XCTAssertEqual(Array(processed.imageData.prefix(2)), [0xff, 0xd8])
    }

    func testNativePhotoProcessingRejectsInvalidData() {
        XCTAssertNil(PhotoProcessor.process(Data("not a picture".utf8)))
    }
}
#endif
