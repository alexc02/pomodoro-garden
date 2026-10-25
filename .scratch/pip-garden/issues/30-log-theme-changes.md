# 30 — Log garden-theme changes

**What to build:** changing the garden theme records a `settings_changed` event, as every other user-chosen setting already does. PRD v2.2 §7.1. Found by the gap review (finding A4): `SettingKey` in `packages/pomodoro_domain/lib/src/analytics/analytics_event.dart` lists ten settings and not the theme, so a change made in the theme picker records nothing.

**Blocked by:** nothing.

**Status:** done.

- [x] `SettingKey` gains `gardenTheme('garden_theme')`
- [x] `AnalyticsEvent.forSettingsChange` compares the theme and emits one `settings_changed` with the old and new theme names when it differs
- [x] Domain test: a theme change yields exactly one event with the right key and values; a change to anything else yields none for the theme
- [x] App test: choosing a theme in the theme picker writes the event to the local log
- [x] No schema change: the log stores the key as text
- [x] `flutter analyze --fatal-infos` clean; app and domain suites green

## What was built

| Where | What |
|---|---|
| `packages/pomodoro_domain/lib/src/analytics/analytics_event.dart` | `SettingKey.gardenTheme('garden_theme')`, compared in `forSettingsChange` with the theme's name as the value |
| `packages/pomodoro_domain/test/analytics/analytics_event_test.dart` | A theme change is exactly one `settings_changed`, `zen` → `tropical` |
| `test/analytics/settings_events_test.dart` | Picking a theme in the real picker, through Settings, writes the event to the local log |

The picker already saved through `SettingsController.change`, the one place events are recorded, so no UI code changed. Suites: 959 app and 383 domain tests pass; analyzer clean.

**Verification gap:** none; nothing here is device-specific.
