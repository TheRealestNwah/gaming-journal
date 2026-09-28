# Roadmap

Gaming Journal is a **session journal**: a diary of play sessions. A game is just the title on a session — there is no separate game library. All data is entered by hand; there is no online game database.

| # | Milestone | Scope |
|---|-----------|-------|
| M0 | Housekeeping | Branch protection, CLAUDE.md, this roadmap |
| M1 | Session model | `PlaySession` (title, platform, start, duration, enjoyment, mood, notes, tags, milestone), versioned schema, CloudKit-safe |
| M2 | Session editor | Add/edit form, title autocomplete from history, platform presets remembered per game, quick duration chips |
| M3 | Journal timeline | Grouped by day with totals, search, filters (game/platform/tag/milestones), undo delete, detail view |
| M4 | Live timer | Start/pause/stop session timer that survives relaunch, prefills the editor |
| M5 | Screenshots | Attach photos to sessions (external storage), thumbnails and viewer |
| M6 | Per-game view | Games derived from sessions: totals, averages, timeline; rename/merge titles |
| M7 | Stats & charts | Hours per week/month, top games, platform split, streaks, heatmap, enjoyment trend |
| M8 | Export/import | JSON backup/restore (dedupe by ID), CSV export, Settings screen |
| M9 | Widgets | Last/current session, weekly hours, start-session button |
| M10 | iCloud sync | CloudKit-backed store behind a Settings toggle (needs a paid developer team to verify) |
| M11 | Polish | Onboarding, accessibility, String Catalog, UI smoke tests in CI |

Needs a human: a real app icon, and on-device checks of widgets, photo picking and iCloud sync.
