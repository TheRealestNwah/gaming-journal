# Roadmap

## Vision

The journal your character keeps, like the in-game journal in Skyrim or Morrowind. One journal per character; each is a book of dated entries on aged pages, turned like a book. Writing is a blank page: the in-game date, the words, maybe a picture. Nothing else on screen.

All data is entered by hand; there is no online game database and no account.

## Current direction (September 2026)

The app was rebuilt around this simpler idea. The notebook, party, emotion, bond, chapter, stats and play-session features below were removed; their tables are kept as history.

| Item | Issue |
|------|-------|
| Journals and entries on a fresh, simpler data model | #116 |
| Journal shelf, paged reader and writer in the in-game journal style | #117 |
| Remove the party, emotions, bonds, chapters, stats and play sessions | #119 |
| Point widgets, Siri, Spotlight, reminders, backup and export at journals | #118 |

## Data model

| Model | Key fields |
|---|---|
| **Journal** (one character) | character name, race/class/title, game, cover colour |
| **Entry** | text, in-game date, date written, pictures |

## History: the notebook app

## Build order

| # | Item | Issue |
|---|------|-------|
| R1 | Warm RPG theme system, applied to existing screens | #32 |
| R2 | Notebook, character and entry data model | #33 |
| R3 | Library home with notebook covers | #34 |
| R4 | Party: characters with portraits and backstory | #35 |
| R5 | Entry editor and Chronicle timeline (with Atlas) | #36 |
| R6 | Bonds and character sheet with emotional arc | #37 |
| R7 | In-character writing prompts | #38 |
| R8 | Play sessions inside notebooks | #39 |
| R9 | Journey stats per notebook and overall | #40 |
| R10 | Backup v2, Markdown book export, widgets for notebooks | #41 |
| R11 | New navigation: retire the Journal and Games tabs | #42 |
| R12 | Onboarding, empty states and ember effects in the new tone | #43 |
| R13 | Update UI smoke tests for the notebook flows | #44 |

## Next

Approved features, in build order. Chapters come first because they carry schema V2 (which also adds notebook pinning for R16).

| # | Item | Issue |
|---|------|-------|
| R14 | Chapters and acts for the Chronicle, on schema V2 | #63 |
| R15 | Search entries across all notebooks | #64 |
| R16 | Sort, filter and pin notebooks in the Library | #65 |
| R17 | Recover unsaved entries | #66 |
| R18 | Campfire reminders to write | #67 |
| R19 | Dictate entries | #68 |
| R20 | Lock the journal with Face ID | #69 |
| R21 | Find entries and notebooks in Spotlight | #70 |
| R22 | Tale's end recap when a notebook is completed | #71 |
| R23 | Quick write as a character from Siri, Shortcuts and the Lock Screen | #72 |
| R24 | Export a notebook as a styled PDF book | #73 |
| R25 | Share an entry as an image card | #74 |
| R26 | Accessibility pass across the notebook screens | #75 |
| R27 | iPad layout with Library, Chronicle and entry side by side | #76 |

Not planned for now: NPC codex, bond web, quest log, keepsakes, New Game+ and screenshot suggestions.

All of R1–R27 shipped, then most of it was removed in the September 2026 rebuild (#116–#119).

App name: Hearthbound (#45). Internal identifiers keep the `GamingJournal` names.

Needs a human: on-device checks of widgets, photo picking and iCloud sync (#30).

## Done (first version, session journal)

Session model, editor, timeline, live timer, photos, per-game view, stats, backup/export, widgets, optional iCloud sync, UI smoke tests, onboarding. These are reworked into the notebook app by the items above rather than removed.
