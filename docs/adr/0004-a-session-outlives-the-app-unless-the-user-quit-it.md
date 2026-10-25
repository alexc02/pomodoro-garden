# A session outlives the app unless the user quit it

If the app launches and finds an unfinished session on disk, it restores it and carries
on from wherever the wall clock says it should be. The exception is a session the user
force-quit: that one is marked voided at the moment of the quit, so there's nothing to
restore next time.

## Why

"The process died with an open row on disk" looks the same whether the system killed the
app or the user swiped it away. Nothing at launch can tell the two apart (a heartbeat goes
stale either way), so the difference has to be recorded when it happens.

`SessionLifecycle` listens for `AppLifecycleState.detached` and voids the session there.
Any other way the process ends leaves the row open, and an open row gets restored.

| How it ended | Signal | Result |
|---|---|---|
| Backgrounded | `inactive` / `hidden` / `paused` | nothing, session keeps running |
| Killed by the system, OOM, crash | none | restored on next launch |
| Force-quit by the user | `detached` | voided |

## Trade-offs

- The `detached` write is best-effort: it's a SQLite write during teardown. If it doesn't
  land, the session gets restored instead of voided. That's the better way to fail.
- iOS doesn't always send it. An app that's already suspended gets killed without notice,
  which is the usual case for a swipe in the app switcher, so on iOS a force-quit often
  looks like a system kill. Android does call `onDestroy` on a task swipe. Checking the
  Live Activity state at launch could close this gap later.
- A session that ran out while the app was dead still completes on the next launch, so a
  user who reopens the app a day later still gets the plant.

## Consequences

- `FocusSession` has a `SessionOutcome` (`completed`, `cancelled`, `voided`) instead of a
  `completed` flag. Cancelled and voided both earn nothing, but they're kept separate for
  the event log.
- "In flight" means `outcome IS NULL`.
- The schema 4 migration marks every unfinished row from older versions as voided, so an
  upgrade doesn't restore a session someone abandoned weeks ago.
