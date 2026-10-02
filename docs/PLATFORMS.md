# iPad and native Mac

The universal iOS app targets iPhone and iPad (iOS/iPadOS 17+). CI runs the normal smoke suite on both, then iPad rotation/spread acceptance, and exports screenshots. Portrait and narrow windows use one page; landscape windows at least 960 points wide use two. Simulator checks do not replace #30: real keyboard, VoiceOver, Stage Manager, camera, signing and two-device iCloud acceptance remain manual.

## Native Mac

Open `GamingJournal.xcodeproj` on a Mac and select **Hearthbound (Mac)**. This is a native macOS 14+ SwiftUI/AppKit target, not Catalyst. **Hearthbound (Mac Free Team)** uses the existing `.free` identities with iCloud disabled. CI builds/tests the standard Mac scheme; free-team signing needs a device-side check.

The Mac target shares models, migrations, local storage, optional iCloud sync, journal reading/writing, search, draft recovery, contents, bookmarks, JSON backup/import, Markdown/PDF export, photo processing and the visual theme. Native sheets, file photo import and system image sharing replace iOS presentation. The reader uses the shared pagination and arrow-key controls without a page curl. One resizable window is intentional to avoid simultaneous editors overwriting the same saved draft.

The iOS bundle IDs, widgets and cloud container have not been renamed. The native Mac app uses the same main bundle identity and CloudKit container. Signed distribution must provision the Mac app group, iCloud and push capabilities. CI uses unsigned, isolated in-memory app data and cannot validate signing, iCloud, Touch ID or notification delivery.

Initial Mac limits: no app-lock UI, camera capture or desktop widget extension. iOS locking stays unchanged. Mac lock/privacy coverage and desktop widgets need their own implementation and acceptance before being advertised. Test Shortcuts/Spotlight, notifications, Photos library authorization, native sharing and sandboxed file dialogs on a signed build. Confirm import/export round trips and cross-device edits/deletes/photos with a test iCloud account before release.

## Validation

CI keeps simulator parallel testing disabled and runs iPhone then iPad on one runner, reusing the iOS build. It then builds/tests the native Mac scheme with shared unit tests and Mac-specific UI smoke tests. Artifacts separate screenshots by platform. No release or tag is authorized by these changes.
