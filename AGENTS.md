# Hearthbound — notes for Codex

iOS 17+ SwiftUI + SwiftData app: role-playing notebooks for game playthroughs. Each notebook holds a party of characters and their in-character entries (emotions, places, quests, bonds). Play-session tracking is a secondary feature. No accounts, no online game database.

The app is called **Hearthbound**. Its Xcode targets, schemes, bundle IDs, app group and iCloud container keep the old `GamingJournal` names on purpose: renaming them would cut off existing data, widgets and sync. Only user-facing text uses the new name.

## Layout
- `GamingJournal/Models/` — SwiftData models (versioned schema, CloudKit-compatible)
- `GamingJournal/Services/` — plain Swift logic (formatting, stats, export…); keep UI-free so it's unit-testable
- `GamingJournal/Views/<Feature>/` — SwiftUI views
- `GamingJournalTests/` — XCTest unit tests
- The Xcode project uses synchronized folders: new files in these folders are picked up without editing `project.pbxproj`. Only new targets, entitlements or build settings need pbxproj edits.

## Rules
- **CI is the only build check.** Development happens on Windows, so nothing is compiled locally. Read the `xcodebuild-logs` artifact when a run fails.
- SwiftData models must stay CloudKit-safe: every property has a default or is optional, no `@Attribute(.unique)`, relationships optional. Add schema changes as a new `VersionedSchema` plus a migration stage.
- Put logic in `Services/` with tests; views stay thin.
- The `FreeTeam` build configuration (scheme **Hearthbound (Free Team)**) is for testing on a device with a free Apple ID: `.free` bundle IDs and app group, no iCloud or push, and the `FREE_TEAM` Swift condition. CI never builds it, so keep `#if FREE_TEAM` branches tiny, and add any new build setting or entitlement to it too.
- One issue per work item. When several items are green-lit together, build them on one branch and open one PR that closes all of them. A single item still gets its own PR. `main` is protected and requires the `Build & test (iOS Simulator)` check.

## CI
- macOS runners are the bottleneck: only a few run at once, and every run holds one for ~5 min. Avoid pushing several PR branches at the same time. Push or rebase them one after another so they don't queue behind each other.
- CI runs on pull requests only (not on pushes to `main`). Docs-only PRs (`docs/`, `*.md`) skip the macOS job, and the skipped job still satisfies the required check. Use "Run workflow" (workflow_dispatch) to test `main` by hand.
- Unit and UI smoke tests run in one `xcodebuild test-without-building` call on a simulator booted during the build. Parallel testing stays off, because cloning the simulator costs minutes while the suite takes seconds. Keep it that way when editing `.github/workflows/ci.yml`.

## Tone and theme
- Warm RPG adventure feel: parchment, ember, crimson, gold; serif (New York) for titles and entry text.
- Use the shared theme tokens and components (see `Views/Theme/` once it lands) rather than raw colours or fonts.
- Copy is in-world but clear ("Begin a new tale", not jokes that hide meaning). Every decorative effect respects Reduce Motion and keeps WCAG AA contrast.

## Conventions
- Issue and PR titles are plain sentence-case descriptions (no "M7:" / "R3:" prefixes). PR bodies start with `Closes #N` (one line per issue when a PR covers several), then `Roadmap: R3` when it applies.

## Roadmap
See [docs/ROADMAP.md](docs/ROADMAP.md).

## Workflow
The owner's Claude setup follows these too; keep them when working here.
- File an issue before starting any work item (feature, bug, chore, refactor). Typo and comment-only fixes can go straight to a PR.
- Label every issue and PR from the repo's label set (`bug`, `enhancement`, `documentation`, `chore`, `ci`, …).
- Commit and PR titles are short imperative summaries with the issue number in parentheses, e.g. "Fix X (#12)".
- Work on a branch and open a PR; never push to `main` directly, force-push or tag a release without asking the owner.
- Right after opening a PR against `main`, enable auto-merge: `gh pr merge <n> --auto --squash --delete-branch`. Don't auto-merge a PR whose base isn't `main`.
- Claude and Codex may work on this repo at the same time. Each session uses its own git worktree so they don't edit each other's files.

## Keeping this file current
`CLAUDE.md` holds the same notes for Claude. When one changes, update the other to match.
