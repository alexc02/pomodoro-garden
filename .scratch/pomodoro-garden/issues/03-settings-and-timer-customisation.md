# 03 — Settings screen and timer customisation

**What to build:** The user opens settings, changes their preferred session length, and the next session they start uses it. Settings survive relaunch. This ticket creates the settings surface and persistence; every later feature ticket adds its own row here rather than a single late settings ticket.

**Blocked by:** 02

**Status:** completed

- [x] Session length adjustable across 5–120 minutes, break length across 1–30 minutes, and long-break-after-N across 2–6
- [x] The three presets from REQ-006 (15 Short / 25 Classic / 50 Deep) are one-tap choices alongside the custom control
- [x] Changing session length changes the duration of the *next* session started; it never mutates a session already running
- [x] All settings persist to SQLite and are restored on relaunch on both platforms
- [x] Defaults on first run: 25-minute session, 5-minute break, long break after 4
- [x] Settings are read through a single typed accessor, not scattered raw key lookups, so later tickets can add fields without touching call sites
- [x] The screen follows the botanical/calm aesthetic and works in light and dark mode

## How it was built

**The bounds live in one place.** `SettingsRanges` in the domain holds REQ-030's three
ranges, and both the control that offers a value and the code that accepts one read them
from there — so a slider cannot offer a length the settings would refuse.

**Presets are a session length with a name on it,** not a fourth setting. `SessionPreset`
is a domain enum; tapping a chip writes the same `sessionLength` the slider writes, and
`GardenSettings.preset` is what tells the screen which chip to show as chosen. Move the
slider off a preset's length and no chip is selected, because there is nothing else it
could mean.

**`settingsProvider` is the accessor,** and it hands out a synchronous `GardenSettings`.
`SettingsGate` reads the stored settings before the shell is built, so no screen carries a
loading branch and there is no window in which a fast START could run on defaults the user
replaced three launches ago. See
`docs/adr/0004-settings-are-read-once-before-the-app-opens.md`.

**A change reaches the next session and no other.** `SessionController.start` reads the
session length at the tap and hands it to the machine; the running session keeps the
planned duration it began with and never consults the setting again.

**Schema version 2.** `settings` is a single row, enforced by a check constraint rather
than by convention. `AppDatabase.migration` now walks one version at a time, and
`test/data/database_migration_test.dart` upgrades a database built by raw SQL at version 1
— the only way to show that an installed app's sessions survive the upgrade.

## What later tickets inherit

Adding a setting is: a field on `GardenSettings`, a column plus two lines of mapping in
`DriftSettingsRepository`, a schema bump with a migration step and a case in the migration
test, and a row on the settings screen. No existing call site changes.

`breakLength` and `longBreakAfter` are settable and stored from this ticket, but nothing
reads them yet — ticket 09 is the first to start a break with them.

## Checks

`./scripts/check.sh` is green: `flutter analyze --fatal-infos` clean, 93 app tests, 41
domain tests.

Not verified on a device: this workstation has no iOS simulator or Android emulator, so
"restored on relaunch on both platforms" is covered by the kill-and-relaunch tests against
a real SQLite file rather than by a run on hardware.
