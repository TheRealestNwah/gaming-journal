# Gaming Journal — notes for Claude

iOS 17+ SwiftUI + SwiftData app: role-playing notebooks for game playthroughs. Each notebook holds a party of characters and their in-character entries (emotions, places, quests, bonds). Play-session tracking is a secondary feature. No accounts, no online game database.

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

## Tone and theme
- Warm RPG adventure feel: parchment, ember, crimson, gold; serif (New York) for titles and entry text.
- Use the shared theme tokens and components (see `Views/Theme/` once it lands) rather than raw colours or fonts.
- Copy is in-world but clear ("Begin a new tale", not jokes that hide meaning). Every decorative effect respects Reduce Motion and keeps WCAG AA contrast.

## Conventions
- Issue and PR titles are plain sentence-case descriptions (no "M7:" / "R3:" prefixes). PR bodies start with `Closes #N`, then `Roadmap: R3` when it applies.

## Roadmap
See [docs/ROADMAP.md](docs/ROADMAP.md).
