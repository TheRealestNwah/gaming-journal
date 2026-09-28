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

## CI

GitHub Actions builds the app and runs the unit tests on every pull request and push to `main`.

## License

MIT — see [LICENSE](LICENSE).
