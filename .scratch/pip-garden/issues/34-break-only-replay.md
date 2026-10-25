# 34 — The break runs while the phone is locked

**What to build:** with auto-start break on, a session that ends while the app is away is followed by its break **anchored at the session's end**, and the break's end is announced by a notification on time. The next **focus session is never started in the background**. PRD v2.2 REQ-032. Found by the gap review (finding B2): today the "Start breaks automatically" switch does nothing for a user whose phone is face-down.

ADR 0008 rejected replaying the cycle because replaying a *focus session* would plant a reward for time spent with the phone in a pocket. That reasoning stands. It does not apply to a break, which earns nothing, and the cycle can stop after the break rather than replay everything.

**Blocked by:** nothing. Do it after 33 so both garden-bar states are exercised by the tests here.

**Status:** done.

- [x] When a running session is found complete on resume, with auto-start break on, its break is anchored at the session's **due time**, not at the moment it was noticed. If that break has also already ended, the app lands in `breakOver`, exactly as a break that ran in the foreground does
- [x] When the app leaves the foreground with a running session and auto-start break on, **two** notifications are scheduled: the session's end, and the break's end (session due + break length, long or short per the cycle position). Both are cancelled on return
- [x] A paused session schedules neither, as today
- [x] Auto-start next session is unchanged: it acts only when the app is awake, from the instant noticed
- [x] The cycle position counts correctly through a replayed break, so the long break still falls after N sessions
- [x] The break notification uses the chosen end sound, as today's break notice does
- [x] Turning auto-start break on while sitting on a completed session still does not start a break (ADR 0008's "endings are not states" rule)
- [x] Session-machine tests for: backgrounded through the session only; through the session and the break; long break at the end of a cycle; auto-start break off (no change from today)
- [x] **New ADR** amending 0008, recording why the break replays and the session does not
- [x] `flutter analyze --fatal-infos` clean; app and domain suites green

## What was built

| Where | What |
|---|---|
| `packages/pomodoro_domain/lib/src/session/session_machine.dart` | `startBreak(offer, at:)`: a break may be anchored at an earlier instant, never a later one |
| `lib/src/session/session_providers.dart` | `startBreak({from})`; `_autoStart` starts the auto break at the completed session's `dueAt`, and if that break is already over, runs once more so *Start sessions automatically* can follow from now |
| `lib/src/notifications/session_notifications.dart`, `local_session_notifications.dart` | `scheduleFollowUp`, posted under its own notification id (2); `cancelCompletion` withdraws both |
| `lib/src/session/session_announcer.dart` | On leaving the foreground with a running session and auto-start break on, schedules the break's end at session due + the length of the break the next cycle position earns (short or long) |
| `test/support/announcement_fakes.dart` | The fake holds `pendingFollowUp` and `followUps` |
| `docs/adr/0022-a-break-replays-and-a-session-never-does.md` | **New ADR**, amending 0008 |
| `packages/pomodoro_domain/test/session/break_cycle_test.dart` | Four tests: counts from the anchor, already over when all of it passed, never in the future, the cycle is unchanged |
| `test/features/timer/break_and_cycle_test.dart` | Eight new widget tests (replay mid-break, over on return and silent, follow-up scheduled, withdrawn on return, the long break, none for a held session, none without the switch, a hand-taken break starts when taken). **One existing test rewritten:** "and the cycle survives backgrounding" asserted 0008's old rule (a fresh break on return); it now asserts the new one (the break is long over, and the next session starts on return) |

Suites: 986 app and 396 domain tests pass; analyzer clean.

**Verification gap:** two scheduled notifications delivered on time by each OS, with the
phone locked, is a device check (ticket 39): Android exact alarms under two ids, and iOS
pending notifications. Nothing here could be compiled against a real device.
