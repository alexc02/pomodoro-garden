# 02 — Start and complete a focus session

**What to build:** The user taps START and a 25-minute focus session runs, counting down on a circular progress ring with the remaining time in the centre. When it reaches zero the session completes. The completed session is recorded and is still there after the app is killed and relaunched.

This ticket establishes the timer state machine that every later ticket depends on, and the SQLite schema. Run `/domain-modeling` on the session lifecycle before writing code, and build the state machine with `/tdd` — it is the spine of the product and the one place where test coverage matters most.

**Blocked by:** 01

**Status:** done — with one acceptance criterion partly unverified on this machine, see *Verification gap* below.

- [x] Tapping START begins a session; the ring fills proportionally and the countdown decrements once per second
- [x] Elapsed time is derived from a wall-clock anchor, never accumulated from ticks — a session must not drift when the UI thread stalls or frames are dropped
- [x] Timer accuracy within ±1 second over a 120-minute session (verifiable in the domain layer with an injected clock, without waiting two hours)
- [x] The state machine is a pure Dart unit with no Flutter, platform or clock dependencies, driven by an injectable time source and covered by tests for every legal and illegal transition
- [x] Session records persist to SQLite with id, start time, duration, completion flag, and paused-duration fields; the schema has a migration path from empty
- [~] Completing a session marks it completed and it is present after a full app kill and relaunch — **verified against a real database file, but not on either platform's own storage**, see *Verification gap*
- [x] The timer screen renders correctly in light and dark mode using ticket 01's tokens

---

## What was built

`./scripts/check.sh` is green: analysis clean across the workspace, **60 app tests** and **26 domain tests**.

**The domain model came first.** `/domain-modeling` produced `CONTEXT.md` — the project had no glossary — pinning the words the rest of the product has to use: *anchor*, *planned duration*, *elapsed*, *completed* (as distinct from *ended*, *cancelled* and *voided*), *tick*, *poll*. Three ADRs record the decisions that were genuinely hard to reverse: `docs/adr/0001` (anchored time), `0002` (sessions written at start), `0003` (durations stored in seconds).

**The state machine** is `packages/pomodoro_domain/lib/src/session/session_machine.dart` — pure Dart, no Flutter, time only ever through the injected `Clock`. Two commands, `start` and `poll`, and a derived `snapshot`. Built with `/tdd`, one slice at a time.

Its shape is the point: **completion is noticed, not fired**. Nothing inside the machine goes off at the end of a session. The clock passes `anchor + plannedDuration`, and the next look sees it. That is what makes a session that ended in the user's pocket end at the right instant — `endedAt` is `anchor + plannedDuration`, not the moment the app noticed — and it is what tickets 05 and 06 will need for cold-start restore and background completion.

`poll()` is a latch: it hands the completed session over exactly once, for the caller to record. `start()` refuses to start over a session whose completion has not been collected yet, so a completion the user sat through cannot be silently dropped by a fast finger on START.

**Accuracy.** The ±1s-over-120-minutes requirement is a domain test that polls ~7,400 times at jittery intervals and asserts the error at every step, running in milliseconds. It was checked against a planted tick-accumulating implementation, which drifts past a second after **24 seconds** — the test bites rather than merely passing.

**Persistence.** Drift over SQLite: `sessions(id, startedAt, durationSeconds, completed, pausedSeconds, endedAt)`, schema version 1, `onCreate` creating everything from empty. The repository is a port on the domain side (`SessionRepository`) with the Drift adapter in the app, so the domain still knows nothing about columns. Tested against real in-memory SQLite rather than a fake, including the UTC round trip — SQLite has no date type, and the anchor is the value the whole timer rests on.

**The screen.** `SessionRing` (a `CustomPainter` arc from twelve o'clock) with the countdown in tabular digits at its centre, START, and a live count of sessions grown. All colour and type from ticket 01's tokens; light and dark both asserted against `GardenColors`. The ring and the type scale with the viewport, so a small phone at a large text scale does not overflow.

**The one-second timer exists only to repaint.** It re-aims at the next second boundary each time rather than running periodically, because a periodic timer fires *no sooner* than its period and slides later and later — which on a countdown shows up as a second visibly skipped. Dropping its ticks costs a stale frame, never session time; `test/features/timer/timer_screen_test.dart` stalls the UI for ten minutes and the countdown lands exactly where the wall clock says.

## Decisions worth knowing downstream

**Sessions are written at START, not at completion.** `sessions` therefore holds rows that never completed. **Every query that counts sessions must filter on `completed`** — total sessions, garden level, plot count, streaks and lifetime focus time all derive from this table, and each is wrong by the number of abandoned sessions if it forgets. ADR 0002.

**`durationSeconds`, not PRD §4.3's `durationMinutes`.** A `Duration` does not round-trip through minutes, and a lossy mapping at the persistence boundary has to round silently or throw. PRD §4.3 has been corrected to match. ADR 0003.

**A completed session stays completed.** Phase is derived from the clock, *except* that a session whose record says it completed can never go back to running. Found by `/code-review`: without it, a backwards clock correction after a completion put the finished session back on the ring to be counted down a second time, while `poll()` could never re-complete it. Now tested.

**`SessionController` reads its ports rather than watching them.** The machine holds the running session; rebuilding it on a provider change would drop a session mid-flight. It also reschedules the ticker on rebuild, so a rebuild cannot freeze a countdown while the session underneath carries on.

## Scope notes

Two things here that the ticket did not literally ask for, both deliberate:

- **"N sessions grown" on the timer screen.** The only on-screen evidence for the relaunch criterion — the garden (07) and journal (15) do not exist yet. It reads from the database, not from memory, which is the whole point.
- **Backwards-clock clamping.** Ticket 05 owns what a clock change *means*; what could not wait is that elapsed time never goes negative, since a negative progress value reaches the ring painter.

Pause and cancel are ticket 05's, and are deliberately absent: `pausedDuration` exists on the record and in the schema (this ticket's criterion) and is always zero.

## Verification gap

The relaunch criterion is verified as far as this machine allows and no further:

- **What was verified.** `test/features/timer/session_persistence_test.dart` runs a session to completion against a **real SQLite file**, tears the whole app down — widget tree, provider scope and connection — reopens the file in a fresh app, and finds the completed session with its anchor, duration, completion flag and end instant intact. A session that never completed is checked *not* to count.
- **What was not.** Neither platform's own storage path. `getApplicationDocumentsDirectory` is not exercised by a host test, and the same hardware limits as ticket 01 apply: iOS needs macOS and Xcode, and this container has no `/dev/kvm` for an Android emulator.

**Still to do on suitable hardware:** run a session to completion on an iOS 17 simulator and an API 26 emulator, kill the app, relaunch, and confirm the session is still counted.

*Per `issues/README.md`, nothing was committed — the work is left in the working tree, and no git repository was created.*
