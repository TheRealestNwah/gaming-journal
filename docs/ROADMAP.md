# Roadmap

## Vision

The journal your character keeps, like the in-game journal in Skyrim or Morrowind. One journal per character; each is a book of dated entries on aged pages, turned like a book. Writing is a blank page: the in-game date, the words, maybe a picture. Nothing else on screen.

All data is entered by hand; there is no online game database and no account.

## Data model

| Model | Key fields |
|---|---|
| **Journal** (one character) | character name, race/class/title, game, cover colour |
| **Entry** | text, in-game date, place, date written, pictures |

A journal's ribbon is kept per device in UserDefaults, not in the model.

## Built

| Item | Issue |
|------|-------|
| Journals and entries on a fresh, simpler data model | #116 |
| Journal shelf, paged reader and writer in the in-game journal style | #117 |
| Widgets, Siri, Spotlight, reminders, backup and export for journals | #118 |
| Remove the party, emotions, bonds, chapters, stats and play sessions | #119 |
| IM Fell English, the old-book font | #121 |
| Search entries across journals | #123 |
| Contents page to jump to an entry | #124 |
| Ribbon bookmark so a journal reopens where you left off | #125 |
| Pictures in the PDF book export | #126 |

## Ideas

Not planned yet; each needs the owner's go-ahead.

- Share an entry as an image card
- iPad layout with two facing pages

Removed on purpose, not coming back unless the owner asks: party, emotions, bonds, chapters, stats and play sessions.

Needs a human: on-device checks of widgets, photo picking, dictation and iCloud sync (#30).

## History

Before September 2026 Hearthbound was a notebook app with a party of characters, bonds, chapters, play sessions and stats (roadmap items R1–R27, issues #32–#76). The rebuild (#116–#119) replaced it with one plain journal per character; see the git history for the old roadmap.
