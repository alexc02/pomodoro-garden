# 33 — A timer bar on the garden

**What to build:** a compact timer bar along the bottom of the garden screen, so a session starts with **one tap** from the screen the app opens on. US-006 is P0, and today it takes two taps (switch to the Timer tab, then START). PRD v2.2 §5.2, Screen 1 "As built".

**Blocked by:** nothing.

**Status:** done.

- [x] **Idle (or break over):** shows the next session's length and a START button. One tap starts the session, switches to the Timer tab so the seed drop is seen, and plays the same button-tap micro-sound the timer's START does
- [x] **Running or paused:** shows the live countdown (and "Paused" when held); a tap switches to the Timer tab. No pause or cancel controls here: they stay on the Timer tab
- [x] **On a break:** shows the break countdown; a tap switches to the Timer tab
- [x] **Completed:** shows that the session finished; a tap switches to the Timer tab, where the break is offered
- [x] Hidden while arranging decor (REQ-040)
- [x] Shares the bottom edge with the garden's captions (the empty-garden line and the full-garden line) without overlapping them. *On a garden under 240 px tall the caption is dropped and the bar kept: found by `app_shell_test.dart`'s 320×320 surface, where both together overflowed by 32 px*
- [x] The countdown repaints once a second without rebuilding the garden painter: only `GardenTimerBar` watches the session, so the painter above it is untouched. *The bar has no ticker of its own; it rebuilds when the session controller publishes, which it does whether or not the garden is showing. That costs one small widget rebuild a second, which was judged acceptable*
- [x] Accessible: the bar has a semantic label ("Start a 25-minute session", "18 minutes left, focusing")
- [x] Onboarding's coach marks still point at the right things (the onboarding suites pass unchanged; the marks point at the timer ring, the garden tab and the journal tab, none of which moved)
- [x] `flutter analyze --fatal-infos` clean; app and domain suites green

## What was built

| Where | What |
|---|---|
| `lib/src/features/garden/garden_timer_bar.dart` | `GardenTimerBar`: next session's length and START when idle or after a break; "Focusing · 18:04 left", "Paused · …", "On a break · …" / "Long break · …", or "Session complete" otherwise, each tapping through to the timer. Spoken labels in whole minutes ("Start a 25-minute session", "Focusing, 18 minutes left. Open the timer."). Hidden while arranging |
| `lib/src/features/garden/garden_screen.dart` | Caption and bar stacked along the bottom; the caption is dropped on a garden too short for both |
| `test/features/garden/garden_timer_bar_test.dart` | Eight tests: one tap from launch starts a session and lands on the timer; the length follows settings; the tap sound; the spoken label; running, paused and break states with their countdowns; tap-through to the timer; hidden while arranging |

Suites: 978 app tests pass; analyzer clean.

**Verification gap:** the look of the bar over the real garden on a phone, at large text sizes, needs a device (ticket 39).
