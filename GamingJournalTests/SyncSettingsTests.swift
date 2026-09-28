import XCTest
import SwiftData
@testable import GamingJournal

final class SyncSettingsTests: XCTestCase {
    private let suite = "SyncSettingsTests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testSyncIsOffByDefaultAndPersists() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let settings = SyncSettings(defaults: defaults)
        XCTAssertFalse(settings.isEnabled)
        XCTAssertFalse(settings.lastLaunchFellBack)

        settings.isEnabled = true
        XCTAssertTrue(SyncSettings(defaults: defaults).isEnabled)
    }

    func testLocalOnlyLaunchClearsFallbackFlag() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let settings = SyncSettings(defaults: defaults)
        settings.lastLaunchFellBack = true
        _ = try Persistence.makeAppContainer(settings: settings)
        XCTAssertFalse(settings.lastLaunchFellBack)
    }
}

/// CloudKit mirroring rejects unique attributes and non-optional relationships. Guard the current
/// schema so iCloud sync keeps working after model changes.
final class CloudKitSchemaRulesTests: XCTestCase {
    func testCurrentSchemaIsCloudKitCompatible() {
        let schema = Schema(versionedSchema: SchemaV2.self)
        XCTAssertFalse(schema.entities.isEmpty)
        for entity in schema.entities {
            for attribute in entity.attributes {
                XCTAssertFalse(attribute.isUnique, "\(entity.name).\(attribute.name) must not be unique")
            }
            for relationship in entity.relationships {
                XCTAssertTrue(relationship.isOptional, "\(entity.name).\(relationship.name) must be optional")
            }
        }
    }
}
