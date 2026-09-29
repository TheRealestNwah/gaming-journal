# Roadmap

## Vision

A notebook for each playthrough, written from a role-playing point of view. You start a notebook for a game, add your party, and write in character: what they did, how they felt, where they are and who they trust. Play-time tracking stays as a quiet extra.

**Tone:** a leather-bound adventurer's journal by a campfire. Warm parchment, ember orange, deep crimson and gold, serif type, in-world copy ("Begin a new tale").

All data is entered by hand; there is no online game database and no account.

## Data model

A clean-slate schema (nothing has shipped), CloudKit-safe and versioned from here on.

| Model | Key fields |
|---|---|
| **Notebook** (one playthrough) | title, game, platform, cover style (Ember / Forest / Frost / Arcane / Blood Moon), status (ongoing / completed / abandoned), started date, summary |
| **Character** | name, role or class, portrait, backstory, sigil colour, party order |
| **Entry** | written as a character; title, body, real date plus optional in-game date, emotions, place, quest, photos, turning-point flag |
| **Emotion** (on an entry) | about 16 emotions in 5 groups (Resolve, Fire, Shadow, Warmth, Doubt), intensity 1–3 |
| **Bond** (on an entry) | toward a character or an NPC name, affinity −3…+3, note |
| **PlaySession** | kept; optionally belongs to a notebook |

## Visual system

- Palette: parchment and cream (light), charred wood and dark leather (dark); ember, crimson and gold accents; WCAG AA contrast
- Type: New York serif for titles and entry text, system font for controls
- Paper grain drawn in code, drifting embers and page-turn transitions (off under Reduce Motion), wax-seal badge for turning points
- Shared components: `ParchmentCard`, `EmberButton`, `WaxSeal`, `LeatherCover`, `SectionFlourish`

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

App name: Hearthbound (#45). Internal identifiers keep the `GamingJournal` names.

Needs a human: on-device checks of widgets, photo picking and iCloud sync (#30).

## Done (first version, session journal)

Session model, editor, timeline, live timer, photos, per-game view, stats, backup/export, widgets, optional iCloud sync, UI smoke tests, onboarding. These are reworked into the notebook app by the items above rather than removed.
