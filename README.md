# Gaming Journal — iOS

A SwiftUI app for keeping a journal of the games you play: log sessions, playtime, platform and notes. Everything lives on-device (SwiftData), no account required.

## Status

Early scaffold: a journal list with add/delete and a basic new-entry form.

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
