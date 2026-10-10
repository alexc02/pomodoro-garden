# 31 — Break presets

**What to build:** REQ-007's three break presets, **Short 5 / Standard 10 / Long 15**, as one-tap chips beside the existing 1–30 min break slider, the same way ticket 03 put REQ-006's session presets beside theirs. Found by the gap review (finding A1): no ticket ever owned them.

The presets set the **ordinary** break. The long break stays derived: 3× the break, capped at 30 min (`GardenSettings.longBreakLength`). PRD v2.2 REQ-007.

**Blocked by:** nothing.

**Status:** done.

- [x] A `BreakPreset` enum in the domain, shaped like `SessionPreset`: label, length, and `matching(Duration)` returning null for a length no preset has
- [x] `GardenSettings` gains `breakPreset` and `withBreakPreset`, mirroring `preset` and `withPreset`. No new stored field: a preset is a break length with a name on it
- [x] Settings → Breaks shows the three chips above the break slider; the chip matching the current length is selected, and none is when the slider is off a preset
- [x] Tapping a chip moves the slider, and dragging the slider updates the chip, with no flicker
- [x] Picking a preset records `settings_changed` for `break_length`, through the existing comparison, with no new event code
- [x] Domain and widget tests for all of the above
- [x] `flutter analyze --fatal-infos` clean; app and domain suites green

## Notes

- Choosing **Long 15** gives a 15-minute ordinary break and therefore a 30-minute long break (3× capped). That is the accepted reading; the chip's semantics label should not imply it sets the long break.

## What was built

| Where | What |
|---|---|
| `packages/pomodoro_domain/lib/src/settings/break_preset.dart` | `BreakPreset`: Short 5, Standard 10, Long 15, and `matching` |
| `…/settings/garden_settings.dart` | `breakPreset` and `withBreakPreset`, mirroring `preset` and `withPreset`; nothing new is stored |
| `lib/src/features/settings/settings_screen.dart` | `_PresetChips` made generic over the preset type, and a row of break chips above the break slider. Every chip now has a key (`SettingsKeys.sessionPreset`, `SettingsKeys.breakPreset`) |
| `packages/pomodoro_domain/test/settings/garden_settings_test.dart` | Five tests: the three presets, all reachable by the slider, a preset touches only the break, Long gives a 30-minute long break, and which preset is current |
| `test/features/settings/settings_screen_test.dart` | Five widget tests for the chips. Two existing tests adjusted for the new layout: "a custom length leaves every preset unselected" now checks the session chips by key (the default break is on the Short preset), and the drag-to-bound test scrolls the break slider into view first |

No event code changed: a preset is a break length, so `settings_changed` for `break_length` already covers it. Suites: 964 app and 388 domain tests pass; analyzer clean.

**Verification gap:** none; nothing here is device-specific.
