# Hearthbound — iOS

A role-playing notebook for your game playthroughs. Start a notebook for each playthrough, gather your party and write in character: what they did, how they felt, where they are and who they trust. Play-time tracking is a quiet extra.

Everything lives on-device (SwiftData), with optional iCloud sync. No account and no online game database; you enter everything yourself.

## Features

**Notebooks and party**
- **Library**: every playthrough as a leather-bound cover (Ember, Forest, Frost, Arcane, Blood Moon). Sort, filter by status, pin favourites, and search every entry across all notebooks.
- **Party**: characters with a portrait, role or class, backstory and sigil colour.
- **Character sheet**: each character's bonds and emotional arc over the playthrough.

**Writing**
- **Entries**: written as a character (or the Narrator), with an optional in-game date, emotions and their intensity, place, quest, photos, bonds and a wax-seal turning-point flag.
- **Chronicle**: the notebook's timeline, split into chapters and acts, with an Atlas of places.
- **Writing prompts** in character, **dictation**, and **draft recovery** if the app closes mid-entry.
- **Tale's end recap** when you mark a notebook completed.

**Around iOS**
- **Siri, Shortcuts and the Lock Screen**: start an entry as a chosen character without opening the app first.
- **Widgets**: the latest entry, "Write as…" a character, a quick new entry, now playing, this week's play time and a start-session button.
- **Spotlight**: find notebooks and entries from iOS search.
- **Campfire reminders** (optional) to come back and write.
- **Face ID lock** (optional). While locked, widgets and Spotlight hide your writing.

**Sharing and export**
- **PDF book**: a styled book of a whole notebook.
- **Markdown** export of a notebook, and **share an entry as an image card**.
- **Backup**: JSON export and import of everything, merged so nothing is duplicated, plus CSV of play sessions.

**Play sessions and stats**
- **Play sessions**, optionally inside a notebook, with a live timer that survives the app closing.
- **Journey**: stats per notebook and overall.

**Look and feel**: parchment, ember, crimson and gold, New York serif for titles and entries, and drifting embers and page turns that switch off with Reduce Motion. Works on iPhone and iPad, where the Library sits beside the open notebook.

## Status

The R1–R27 roadmap items are in (see [docs/ROADMAP.md](docs/ROADMAP.md)). Some things still need checking on a real device (#30): widgets, photo picking, iCloud sync, Face ID, dictation and Spotlight.

## Requirements

- Xcode 16+
- iOS 17+

## Building

The app used to be called Gaming Journal. The Xcode project, targets, schemes, bundle IDs, app group and iCloud container keep the `GamingJournal` names, so existing data, widgets and sync keep working.

Open `GamingJournal.xcodeproj` and run the `GamingJournal` scheme, or from the command line:

```sh
xcodebuild test -project GamingJournal.xcodeproj -scheme GamingJournal \
  -destination "platform=iOS Simulator,name=iPhone 16"
```

The project uses Xcode's synchronized folders, so new files under `GamingJournal/` and `GamingJournalTests/` are picked up automatically.

## iCloud sync

Sync is optional and off by default (Settings → iCloud Sync, applied on next launch). It mirrors the SwiftData store to the user's private CloudKit database (`iCloud.com.gamingjournal.GamingJournal`).

To use it you need:

- A paid Apple Developer team selected under Signing & Capabilities for the app and widget targets. The iCloud, Push Notifications and App Groups capabilities are already declared in the entitlements files.
- A real device (or simulator) signed in to iCloud. If the synced store can't be opened, the app falls back to on-device storage and says so in Settings.

CI builds without signing, so it only checks that sync compiles. Syncing between two devices has to be verified by hand.

## CI

GitHub Actions builds the app and runs the unit and UI smoke tests on every pull request. PRs that only touch docs skip the build. To test `main` by hand, use "Run workflow".

## License

MIT — see [LICENSE](LICENSE).
