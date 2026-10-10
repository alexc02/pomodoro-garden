# A session outlives the app unless the user quit it

A session found unfinished on disk at launch is **restored** and carries on from where
the wall clock says it is. The one exception is a session the app was force-quit during:
that one is closed as **voided** at the moment of the force-quit, so the next launch
finds nothing to restore.

## The problem

Ticket 05 asks for two things that describe the same situation:

- Force-quitting during a session voids it: on next launch there is no active session,
  no plant, no completed-session record (REQ-013).
- Cold-starting the app while a session should still be running restores it mid-flight
  with the correct elapsed time and growth stage.

Both are "the process is gone and there is an open row on disk". Nothing about the row
says which of the two happened, and nothing measurable at launch does either: a heartbeat
goes stale in a legitimately suspended app exactly as it does in a killed one.

## The decision

The difference is recorded when it happens rather than inferred afterwards.

`SessionLifecycle` listens for `AppLifecycleState.detached` — the platform saying the
engine is being torn down — and closes the session as voided right there. Every other way
a process can end leaves the row open, and an open row is restored.

So the rule the code implements is not "was the app killed" but **"did anyone tell us the
app was going away"**:

| How it ended | Signal | What happens |
|---|---|---|
| Backgrounded | `inactive` / `hidden` / `paused` | nothing. The session was never interrupted |
| Killed by the system, out of memory, crashed | none | restored on the next launch |
| Force-quit by the user | `detached` | voided; nothing to restore |

Ticket 02's decision to write a row when a session *starts* (ADR 0002) is what makes any
of this possible. There is nothing to restore, and nothing to void, if the first write
happens at the end.

## What this costs

**The `detached` write is best-effort.** It runs while the process is being torn down, and
it is a SQLite write. If it does not land, the row stays open and the session is restored
instead of voided. The degradation is deliberately in that direction: the failure gives
the user back a session they meant to throw away, rather than taking away one they were
in the middle of.

**iOS does not always send it.** `applicationWillTerminate` reaches a foreground or
background app, but an app iOS has already *suspended* is killed without a word — which
is the common case for a swipe in the app switcher. On that path an iOS force-quit reads
as a system kill and the session is restored. Android calls `onDestroy` on a task swipe
and so does send `detached`, which is why the behaviour is not symmetric today.

Ticket 08 is where iOS gets a second signal worth having: a Live Activity ends when its
app is force-quit, and reconciling against one at launch would close the gap. That is a
reason to revisit this, not a reason to hold ticket 05.

**A session that ran out while the app was dead still completes.** Restoring is restoring:
the next poll notices the clock passed the end and the plant is planted. That is ADR
0001's doctrine — completion is noticed, not fired — and ticket 06 owns making it true
for a backgrounded app in the first place. What it means here is that the kind default has
a cost: a user whose app was evicted at minute 3 and who reopens a day later is handed the
plant. Voiding is what stops that from being the *force-quit* user's experience too.

## Consequences

- `FocusSession` carries a `SessionOutcome` (`completed`, `cancelled`, `voided`) rather
  than a `completed` flag alone. Cancelled and voided earn the same nothing, and are told
  apart anyway, because the user's intent differs and ticket 17's event log will want it.
- `sessions` gains an `outcome` column, and "in flight" is `outcome IS NULL` — not
  `endedAt IS NULL`, which was only ever true by coincidence.
- The schema migration to version 4 closes every unfinished row a previous version left
  behind, as voided. Without it, the first launch after upgrading would restore a session
  abandoned weeks ago and hand out a plant for it.
