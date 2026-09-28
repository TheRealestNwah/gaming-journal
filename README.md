# Gaming Journal — iOS

A SwiftUI app for keeping a journal of the games you play: log sessions, playtime, platform and notes. Everything lives on-device (SwiftData), no account required.

## Features

- **Session journal**: log the game, platform, start time, duration, enjoyment (1–5 stars), mood, notes, tags and milestones. Titles autocomplete from your history, and each game remembers its last platform.
- **Timeline**: sessions grouped by day with daily and monthly totals. Search across titles, notes and tags, filter by game, platform, tag or milestones, and swipe to delete with undo.
- **Live timer**: start a timer when you pick up a game and stop it to log the session. It survives the app being closed.
- **Screenshots**: attach photos to a session and view them full screen.
- **Games**: per-game totals, averages and history, derived from your sessions. Rename or merge titles to fix typos.
- **Stats**: hours per day, week or month, top games, platform split, enjoyment trend, streaks and a play heatmap.
- **Backup**: JSON export/import (merged by session, so nothing is duplicated) and CSV export for spreadsheets.
- **Widgets**: now playing / last session, this week's hours, and a start-session button.
- **iCloud sync** (optional): see below.

## Status

Feature-complete for a first version. Some things still need checking on a real device: widgets on the home screen, photo picking and iCloud sync. The app icon is a placeholder.

## Requirements

- Xcode 16+
- iOS 17+

## Building

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

GitHub Actions builds the app and runs the unit tests on every pull request and push to `main`.

## License

MIT — see [LICENSE](LICENSE).
