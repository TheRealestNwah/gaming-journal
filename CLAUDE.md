# Gaming Journal — notes for Claude

iOS 17+ SwiftUI + SwiftData app: a diary of play sessions. No accounts, no online game database.

## Layout
- `GamingJournal/Models/` — SwiftData models (versioned schema, CloudKit-compatible)
- `GamingJournal/Services/` — plain Swift logic (formatting, stats, export…); keep UI-free so it's unit-testable
- `GamingJournal/Views/<Feature>/` — SwiftUI views
- `GamingJournalTests/` — XCTest unit tests
- The Xcode project uses synchronized folders: new files in these folders are picked up without editing `project.pbxproj`. Only new targets, entitlements or build settings need pbxproj edits.

## Rules
- **CI is the only build check.** Development happens on Windows, so nothing is compiled locally. Keep PRs small so CI failures are easy to diagnose; read the `xcodebuild-logs` artifact when a run fails.
- SwiftData models must stay CloudKit-safe: every property has a default or is optional, no `@Attribute(.unique)`, relationships optional. Add schema changes as a new `VersionedSchema` plus a migration stage.
- Put logic in `Services/` with tests; views stay thin.
- One issue → one branch → one PR. `main` is protected and requires the `Build & test (iOS Simulator)` check.

## Roadmap
See [docs/ROADMAP.md](docs/ROADMAP.md).
