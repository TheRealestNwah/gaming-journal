import Foundation
import SwiftData

enum Persistence {
    /// Opens the journal store, migrating older schema versions. Pass `url` to use a specific file
    /// (tests); otherwise the default store location is used.
    static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: GamingJournalMigrationPlan.self,
            configurations: configuration
        )
    }
}
