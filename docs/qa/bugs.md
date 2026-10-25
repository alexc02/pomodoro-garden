# Bug report

Date: 2026-10-25 · Build: `main` @ `548761a` · Found during the QA pass in
[test-plan.md](test-plan.md).

Each bug below reproduced **3 times out of 3** (`flutter test test/qa`, three separate
runs, identical results). Each bug has manual steps for the real app and the automated test
that reproduces it.

**All five are fixed.** Regression tests: `test/session/session_controller_test.dart`
(BUG-01/02/03), `test/features/settings/garden_reset_test.dart` (BUG-04),
`packages/pomodoro_domain/test/session/session_machine_test.dart` (BUG-05),
`packages/pomodoro_domain/test/session/break_cycle_test.dart`, `test/data/garden_reset_test.dart`
and `test/data/database_migration_test.dart` (BUG-01/02), plus every case in `test/qa/`.

**Tip for the manual steps:** in Settings, set **Session length = 5 min**, **Break length = 1 min**
and **Long break after = 2**. The cycle then takes minutes instead of hours.

| ID | Title | Severity | Status |
|---|---|---|---|
| [BUG-01](#bug-01) | Pomodoro cycle resets when the app is relaunched; the long break is skipped | Medium | Fixed 2026-10-25 |
| [BUG-02](#bug-02) | Garden reset doesn't reset the cycle; first session after a reset offers a long break | Low–Medium | Fixed 2026-10-25 |
| [BUG-03](#bug-03) | Two taps on "Plant it" within one frame throw an uncaught `SessionTransitionError` | Low | Fixed 2026-10-25 |
| [BUG-04](#bug-04) | Reset note says "A session or break is running" on the "Session complete" screen | Low | Fixed 2026-10-25 |
| [BUG-05](#bug-05) | A paused session's plant reaches Mature before the session completes (contradicts REQ-016) | Low (spec deviation) | Fixed 2026-10-25 |

---

## BUG-01

**Pomodoro cycle resets when the app is relaunched; the long break is skipped.**

- **Severity:** Medium (core Pomodoro rule REQ-030; a common path on iOS, which reclaims
  backgrounded apps)
- **Test:** `test/qa/qa_flows_test.dart` → TC-12

**Steps to reproduce** (defaults: long break after 4)
1. Open the app → **Timer** tab → tap **Plant it**.
2. Let the session complete. The screen shows "Session complete" and "Take a 5 min break".
3. Tap **Take a 5 min break** and let it run out ("Break over").
4. Repeat steps 1–3 two more times. That's 3 completed sessions.
5. Close the app from the app switcher (no session is running, so nothing is voided), or let the OS
   reclaim it in the background. Open it again.
6. Tap **Plant it** and let the 4th session complete.

**Expected:** the 4th completed session offers **"Take a 15 min long break"**, as it does
when the app stays alive (TC-11 passes).

**Actual:** it offers **"Take a 5 min break"**. The cycle restarted at session one, so the
long break comes only after 4 *more* sessions.

**Root cause:** the cycle position is held only in memory
(`packages/pomodoro_domain/lib/src/session/session_machine.dart:211`,
`int _cyclePosition = 0;`). It is neither persisted nor re-derived from the sessions table
at launch. ADR 0008 says the user's *position* in the cycle is what survives, but it
doesn't survive process death.

---

## BUG-02

**Garden reset doesn't reset the cycle; the first session after a reset offers a long break.**

- **Severity:** Low–Medium
- **Test:** `test/qa/qa_flows_test.dart` → TC-18

**Steps to reproduce** (defaults: long break after 4)
1. Complete 3 sessions, each followed by its break running out (steps 1–4 of BUG-01).
2. Go to **Settings → Reset → Reset your garden** → **Continue** → **Reset my garden**.
   The snack bar says "Your garden's clear…". Journal and garden are empty.
3. Go to **Timer** → **Plant it** and let the session complete.

**Expected:** this is the first session of a fresh garden with no stats, so it offers
**"Take a 5 min break"**.

**Actual:** it offers **"Take a 15 min long break"**. The pre-reset cycle position (3)
carried over.

**Root cause:** `GardenResetController._republish`
(`lib/src/garden/garden_reset_providers.dart:173`) invalidates plants, decor, sessions,
journal and milestones, but not the session controller. The `SessionMachine`'s in-memory
`_cyclePosition` keeps counting from before the reset.

---

## BUG-03

**Two taps on "Plant it" within one frame throw an uncaught `SessionTransitionError`.**

- **Severity:** Low (one session still starts, but an uncaught async error is reported to
  `FlutterError` and to any crash reporting)
- **Test:** `test/qa/qa_flows_test.dart` → TC-07

**Steps to reproduce**
1. Open the app → **Timer** tab, timer idle ("Ready to focus").
2. Tap **Plant it** twice before the next frame rebuilds the button. This happens with a
   very fast double tap while the UI thread is busy (first launch, audio start-up), with
   an automation tool, or with Switch Control. The automated test taps twice with no
   `pump` in between.

**Expected:** one session starts and the second tap is ignored, the way Pause, Resume,
Cancel and "Take a break" already ignore taps that arrive in the wrong phase.

**Actual:** one session starts, and the second tap throws:

```
SessionTransitionError: Bad state: Cannot start a session while 1 is in flight.
#0 SessionMachine.start (session_machine.dart:227)
#1 SessionController.start (session_providers.dart:182)
```

**Root cause:** `SessionController.start()` (`lib/src/session/session_providers.dart:172`)
is the only command without a phase guard. `pause`, `resume` and `cancel` go through `_command`, and
`startBreak` checks `_atRest`, but `start` calls `_machine.start` unconditionally. The same
path is reached by "Plant another" and by auto-start racing a user tap.

---

## BUG-04

**The reset note says "A session or break is running" on the "Session complete" screen.**

- **Severity:** Low (misleading copy; the blocking itself is by design)
- **Test:** `test/qa/qa_flows_test.dart` → TC-19

**Steps to reproduce**
1. **Timer** → **Plant it**, and let the session complete ("Session complete" shown).
2. Don't tap anything on the timer. Go to **Settings** and scroll to **Reset**.

**Expected:** the note explains the real state, for example that a session just finished
and the next one needs to start or be skipped first.

**Actual:** the note reads *"A session or break is running. Finish or cancel it first;
resetting won't end it for you."* Nothing is running, and a completed session can't be
finished or cancelled, so the advice can't be followed. The way out is to start a session
or break and then cancel or skip it.

**Root cause:** `gardenMayBeResetProvider` deliberately returns false for
`SessionPhase.completed` (`lib/src/garden/garden_reset_providers.dart:86`), but
`_ResetDoor` shows one message for every blocked phase
(`lib/src/features/settings/settings_screen.dart:630`).

---

## BUG-05

**A paused session's plant reaches Mature before the session completes.**

- **Severity:** Low. This is a **spec deviation that needs a product decision**: a code
  comment in `SessionMachine.snapshot` describes it as intended, but PRD REQ-016 defines
  Mature's trigger as "Session complete".
- **Test:** `test/qa/qa_domain_test.dart` → TC-23

**Steps to reproduce**
1. In Settings, set **Session length = 10 min**.
2. **Timer** → **Plant it**. Wait 8 minutes (the plant is "Maturing").
3. Tap **Pause** and wait 4 minutes.

**Expected (REQ-016):** the plant stays at Maturing until the session completes.

**Actual:** the plant shows **Mature** while the timer still reads 02:00, paused. Paused
growth at half rate: 8 min + 4 min × 0.5 = 10 min = 100%. The stage-up shimmer and haptic play
for a plant the user can still cancel and lose.

**Root cause:** `growthProgress` is clamped to 1.0, not to just below Mature, while the
session is unfinished (`packages/pomodoro_domain/lib/src/session/session_machine.dart:466`).
