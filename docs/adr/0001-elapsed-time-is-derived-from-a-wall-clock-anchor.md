# Elapsed time is derived from a wall-clock anchor

A focus session stores the UTC instant it started plus its planned duration. Elapsed and
remaining time are computed as `clock.now() - anchor` whenever something asks. There's no
counter that a periodic timer decrements.

A `Timer.periodic` that subtracts a second each tick drifts: Dart timers fire no sooner
than their period and often later, so GC pauses, dropped frames and a suspended isolate
all quietly stretch the session. Over a two-hour session that's well past a second of
error, and a backgrounded app might not tick at all.

What follows from this:

- The one-second timer only exists to repaint the screen. A missed tick is a stale frame,
  not a wrong session.
- A session is over when the clock says so at the moment someone checks. That's what lets
  a session finish while the app was suspended, and lets a cold start restore one
  mid-flight.
- Anchors are UTC, so a session survives a timezone change or DST boundary.
- The device clock can jump backwards. Elapsed is clamped at zero so the UI never shows
  negative time.
