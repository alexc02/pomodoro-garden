# QA test plan and results

Date: 2026-10-25 · Build: `main` @ `548761a` · Flutter 3.44.9 / Dart 3.12.2

## Approach

1. **Familiarisation.** Read the PRD (§3 requirements), CONTEXT.md, the ADRs, the session
   state machine, the session controller, the timer, journal and settings screens, and
   the garden-reset flow. Built the app for the iOS Simulator (iPhone 18 Pro, iOS 27.0)
   and launched it to see the real shell: the Garden, Timer, Journal and Settings tabs, and the live
   "Paused · 24:47 left" pill restored from a previous run.
2. **Baseline.** Ran the existing suites: 1,032 app tests and 396 domain tests, all passing.
3. **Test cases.** Wrote 23 cases covering flows the existing suite does not combine:
   relaunch between sessions, reset mid-cycle, rapid input, and spec boundaries. They live
   in `test/qa/` and drive the real widget tree, the real Drift schema (in memory) and
   a controllable clock. App kills, force-quits and backgrounding use the project's
   own harness (`test/support/app_harness.dart`).
4. **Reproduction rule.** The whole QA suite ran 3 times in fresh processes. Each run
   gave the same result: **18 passed, 5 failed**, with the same five each time. Every failure was then
   checked against the PRD, the ADRs and the existing tests to rule out a wrong expectation
   in the test. One expectation (TC-15) was wrong and was corrected before the three runs.

Run it: `flutter test test/qa` (put `/usr/bin` first on `PATH` on this machine:
`/usr/local/bin/git` is a wrong-architecture binary that breaks the Flutter tool).

## Results

| ID | Area | Test case | Result | Notes |
|---|---|---|---|---|
| TC-01 | Timer | Idle timer shows 25:00, "Ready to focus", "Plant it" | ✅ Pass | REQ-002 |
| TC-02 | Timer | Running session counts down from the wall clock | ✅ Pass | REQ-005 |
| TC-03 | Timer | Completion plants exactly one plant and offers a 5 min break | ✅ Pass | |
| TC-04 | Timer | Pause holds the countdown; completion moves out by paused time | ✅ Pass | REQ-009 |
| TC-05 | Timer | Cancel (confirmed) plants nothing, returns to idle | ✅ Pass | |
| TC-06 | Timer | "Keep focusing" in the cancel dialog keeps the session | ✅ Pass | |
| TC-07 | Timer | Two taps on "Plant it" in one frame start one session, no error | ❌ Fail | [BUG-03](bugs.md#bug-03) |
| TC-08 | Timer | Idle countdown follows the session-length setting (50:00) | ✅ Pass | REQ-006 |
| TC-09 | Interruptions | Force-quit voids the session; nothing planted | ✅ Pass | REQ-013 |
| TC-10 | Interruptions | System kill restores the session; it completes and plants | ✅ Pass | REQ-013 |
| TC-11 | Cycle | 4th session in one run offers the 15 min long break | ✅ Pass | REQ-030 |
| TC-12 | Cycle | Cycle position survives a relaunch between sessions | ❌ Fail | [BUG-01](bugs.md#bug-01) |
| TC-13 | Cycle | Auto-start break starts the break on completion | ✅ Pass | REQ-032 |
| TC-14 | Cycle | Skip break returns to an idle timer | ✅ Pass | |
| TC-15 | Cycle | "Break over" screen shows 00:00 and "Plant it" | ✅ Pass | First expected 25:00. The existing suite pins 00:00 (`break_and_cycle_test.dart:146`), so it's by design and not a bug |
| TC-16 | Garden | 10th completed session awards the Bonsai bonus plant | ✅ Pass | REQ-021 |
| TC-17 | Reset | Reset (double confirmation) clears plants and sessions | ✅ Pass | REQ-036 |
| TC-18 | Reset | After a reset the cycle starts again from session one | ❌ Fail | [BUG-02](bugs.md#bug-02) |
| TC-19 | Reset | On "Session complete" the held-back reset note matches the state | ❌ Fail | [BUG-04](bugs.md#bug-04) |
| TC-20 | Journal | Only completed sessions count (cancelled excluded) | ✅ Pass | REQ-026/028 |
| TC-21 | Domain | Plant tiers at every REQ-015 boundary (5…120 min) | ✅ Pass | |
| TC-22 | Domain | Growth stages at 20 / 50 / 80 / 100 % while running | ✅ Pass | REQ-016 |
| TC-23 | Domain | A paused session doesn't reach Mature before it completes | ❌ Fail | [BUG-05](bugs.md#bug-05) |

## Observations (not reported as bugs)

- **The "Break over" countdown reads 00:00** while "Plant it" will start a 25:00 session.
  This is intended, and an existing test asserts it. It's still worth a design look.
- **Reset is blocked on "Session complete".** This is deliberate (see the doc comment on
  `gardenMayBeResetProvider`). Only the wording shown in that state is wrong (BUG-04).
- **The dev machine's `/usr/local/bin/git` is an x86 binary** ("Bad CPU type"), which
  breaks `flutter` unless `/usr/bin` comes first on `PATH`. This is an environment issue, not an app issue.
