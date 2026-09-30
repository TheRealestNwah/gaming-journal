# Hearthbound — iOS

The journal your character keeps, like the one in an Elder Scrolls game. Start a journal for each character you play, and write their days in their own words: dated in the game's own calendar, on aged pages you turn like a book.

Everything lives on-device (SwiftData), with optional iCloud sync. No account and no online game database; you write everything yourself.

## Features

- **A shelf of journals**, one per character, each a leather-bound book with the character's name, race or class, and game.
- **Pages you turn**: entries read like a book, under their in-game date ("16th of Last Seed, 4E 201"). Prev / Next or a swipe turns the page. A **Contents** page lists every entry with its page number, and a **ribbon** marks your place so the journal reopens there (otherwise it opens on the latest page).
- **Search** every journal from the shelf, or one journal from its Contents, and jump straight to the entry.
- **A blank page to write on**: the in-game date (with a **Next day** button that knows the Elder Scrolls calendar), the words, **dictation**, and pictures pasted in. Unfinished pages are kept if the app closes.
- **Around iOS**: a latest-entry widget, a "Write in…" widget for a chosen journal, a Control Center button, **Siri and Shortcuts** ("Write as Eira in Hearthbound"), **Spotlight**, and an optional evening **reminder**.
- **Face ID lock** (optional). While locked, widgets and Spotlight hide your writing.
- **Export**: a character's journal as a **PDF book** or **Markdown**, and a JSON **backup** of everything that imports without duplicating.

**Look and feel**: aged paper and ink, red rubric dates, IM Fell English throughout (an old-book face by Igino Marini, SIL Open Font License); the shelf is dark wood with gilt. Pages stay paper in dark mode, dimmed like a book read by candlelight.

## Status

Rebuilt around one journal per character (#116–#119). Some things still need checking on a real device (#30).

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

## Running on your own device

With a paid Apple Developer team, pick it under Signing & Capabilities for the **GamingJournal** and **GamingJournalWidgets** targets and run the `GamingJournal` scheme.

With a free Apple ID, use the **Hearthbound (Free Team)** scheme instead:

1. Add your Apple ID in Xcode → Settings → Accounts.
2. Choose the **Hearthbound (Free Team)** scheme and your iPhone as the destination.
3. Under Signing & Capabilities, set Team to "(Your Name) Personal Team" for **GamingJournal** and **GamingJournalWidgets**.
4. Turn on Developer Mode on the iPhone (Settings → Privacy & Security), then Run. The first time, trust your profile under Settings → General → VPN & Device Management.

The Free Team build uses its own `.free` bundle IDs and app group, so a free team never claims the real identifiers. It leaves out iCloud and push, so the iCloud Sync setting is hidden, and apps signed by a free team stop opening after 7 days until you run them from Xcode again.

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
