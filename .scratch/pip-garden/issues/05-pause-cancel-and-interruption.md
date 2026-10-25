# 05 — Pause, cancel, and interruption semantics

**What to build:** Emergencies happen. The user can pause a session and come back to it, and the plant keeps growing while paused — but at half speed, so pausing costs something without being punitive. Cancelling abandons the session. Force-quitting the app voids the session entirely and the seed does not grow. Reopening the app mid-session finds the timer exactly where it should be.

This is where the state machine from ticket 02 earns its keep; extend it with `/tdd` rather than bolting flags onto the UI.

**Blocked by:** 04

**Status:** done — with two criteria qualified, see *Verification gaps* below.

- [x] Pause halts the countdown; resume continues from the paused point with no time lost or gained
- [x] While paused, growth continues at 50% of the normal rate (REQ-009), and total paused duration is recorded on the session
- [x] Cancelling asks for confirmation, then discards the session and its plant — nothing is added to the garden
- [~] Force-quitting during a session voids it: on next launch there is no active session, no plant, and no completed-session record (REQ-013) — **true wherever the platform sends `detached`, which is Android but not a suspended iOS app**, see *Verification gaps*
- [x] Backgrounding is *not* an interruption — the session continues, and returning to the app shows the correct remaining time computed from the wall clock, not from where the UI left off
- [x] Cold-starting the app while a session should still be running restores it mid-flight with the correct elapsed time and growth stage
- [~] Device clock changes and timezone changes during a session do not corrupt elapsed time — **no corrupt state in either direction, but a clock corrected *forwards* still ends the session early**, see *Verification gaps*
- [x] Pause, resume, cancel and void are all covered by state-machine tests

## What was built

**The two criteria that appear to contradict each other, reconciled.** "Force-quitting
voids it" and "cold-starting mid-session restores it" describe the same situation — the
process is gone, an unfinished row is on disk — and nothing measurable at launch tells
them apart. So the difference is *recorded when it happens* rather than inferred
afterwards: `SessionLifecycle` listens for `AppLifecycleState.detached` and closes the
session as voided right there, and every other way a process can end leaves the row open
to be restored. The rule is therefore not "was the app killed" but "did anyone tell us it
was going away". `docs/adr/0005-a-session-outlives-the-app-unless-the-user-quit-it.md`
has the reasoning, the best-effort caveat on the write, and the iOS asymmetry — Android
sends `detached` on a task swipe, iOS does not send it for an app it had already
suspended, and ticket 08's Live Activity is the second signal that would close that gap.

**Pausing without breaking the anchor.** Elapsed time is now the gap to the anchor *less*
the time spent paused — still a subtraction of two clock readings, still never a counter,
so ADR 0001 survives intact. While a pause is open the countdown does not read the clock
at all: it stopped at the instant the pause began and is still standing there, which is
what makes a device clock corrected in either direction mid-pause unable to move it by a
second. A session ends later by exactly what it spent paused.

**REQ-009's half-rate growth is a second progress, not a fudge of the first.**
`SessionSnapshot` carries `progress` (what the ring fills to) and `growthProgress` (what
decides the stage). They are the same number until the first pause, and after that the
plant runs ahead of the countdown — which is what "still growing, at half speed" means,
and it is clamped at mature because that is as grown as a plant gets. The screen says so
in words, with the paused time counting up next to it, so the cost of a pause is watched
rather than discovered.

**A session now ends with an outcome, not a flag.** `SessionOutcome` is `completed`,
`cancelled` or `voided`, null while in flight — and "in flight" became `outcome IS NULL`,
which is what `endedAt IS NULL` had only accidentally been. Cancelled and voided earn the
same nothing and are still told apart, because ADR 0002 promised ticket 05 would and
ticket 17's event log will want it.

**Schema version 4** adds `outcome` and `pausedSince`. The migration's second half matters
more than its first: before this version an unfinished row was just an unfinished row, and
from this version on it is something the app finds at launch and puts back in flight. Left
alone, the first launch after upgrading would restore a session abandoned weeks ago and
hand out a plant for work nobody did — so every unfinished row is closed as voided, which
is what it always was.

**Two gates open the app now.** `SettingsGate`, then `SessionGate`, both showing the same
`OpeningFrame` so two reads look like one wait. The point of the second one is that no
user eleven minutes into a session ever sees a frame saying **Ready to focus**.

## Verification gaps

**Force-quit is only detectable where the platform says so.** Android calls `onDestroy`
on a task swipe and Flutter turns that into `detached`, so a force-quit there is voided.
iOS delivers `applicationWillTerminate` to a foreground or background app but kills a
*suspended* one without a word — and suspended is the usual state of an app being swiped
away in the app switcher. On that path an iOS force-quit is indistinguishable from the
system reclaiming memory, and the session is restored instead. Everything here is verified
against the lifecycle events in a widget test; **neither platform has been exercised on a
real device**, and this box cannot honestly be closed until iOS has been. Ticket 08's Live
Activity is the second signal that would close the gap — an activity ends when its app is
force-quit — and reconciling against one at launch is the fix. ADR 0005 has the reasoning.

**A clock corrected forwards still ends a session early.** Elapsed time is the gap to a
wall-clock anchor, so a +30 minute NTP correction is indistinguishable from thirty minutes
passing, and the session completes and plants. There is no monotonic reference that could
tell the difference *and* survive the process dying, which is the whole reason the anchor
is wall-clock (ADR 0001). What is guaranteed, and tested in both directions, is that
nothing becomes corrupt: elapsed is clamped at both ends, a completed session cannot be
un-completed, a session pays out once, and its end is stamped where the arithmetic says
rather than where the clock jumped to. A held session is immune in both directions,
because a held countdown does not read the clock at all.

## Bugs this ticket found and fixed

- **A resumed session stayed paused on disk.** `insertOnConflictUpdate` built from a Drift
  data class leaves null fields *absent* from the update clause, so a null never overwrote
  what was in the column. Harmless for every field that only fills in; silently wrong for
  `pausedSince`, the one field that has to empty again. `save` now writes an explicit
  companion. Covered by `session_repository_test.dart`.
- **The controls fell below the fold.** The ring took 45% of the height, chosen when a
  running session had nothing to tap. It takes 40% now, the note moved below the buttons,
  and the buttons wrap rather than clip on the smallest supported phone.
- **Confirming a cancel could crash.** If the session finished while the confirmation
  dialog was open, the controls were replaced by START and `_RunningControls` left the
  tree — so the `ref.read` after the await went through a deactivated element and threw.
  The controller is captured before the dialog opens now. Found by the test that pins what
  that race *should* do: a session the user sat all the way through is kept, not thrown
  away, because cancelling something already finished is not a thing that can be done.

## Decisions worth knowing downstream

- **`killApp` and `forceQuitApp` are different things in the harness**, and the difference
  is the whole of REQ-013. Anything testing a relaunch should pick deliberately.
- **The test binding stops producing frames once the app is `paused` or `detached`**, which
  makes `pumpWidget` a silent no-op and leaves the *previous* launch on screen. `killApp`
  walks the binding back to `resumed` first. A relaunch test that skips that passes against
  a tree that should not exist.
- **`pumpApp` no longer uses `pumpAndSettle`.** A launch can now restore a session far
  enough along to put a mature plant on screen, and REQ-023's sway never stops.
- **Ticket 06 inherits one open question:** a session whose planned end passed while the
  process was dead is restored and then completes, planting normally. That is ADR 0001's
  doctrine and what ticket 06 needs, but it means an OS-killed session can pay out for time
  nobody sat through. Worth confirming against the scheduled notification 06 adds.
