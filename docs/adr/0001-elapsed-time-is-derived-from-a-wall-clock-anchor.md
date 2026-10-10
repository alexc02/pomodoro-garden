# Elapsed time is derived from a wall-clock anchor

A focus session stores the UTC instant it began and its planned duration, and computes
elapsed and remaining time as `clock.now() - anchor` every time it is asked. It does not
hold a counter that a periodic timer decrements.

The obvious alternative — a one-second `Timer.periodic` that subtracts a second from a
remaining-time field — drifts. Dart timers fire *no sooner* than their period, never
sooner and often later, so every stalled frame, garbage collection pause or suspended
isolate silently lengthens the session. Over PRD §4.4's 120-minute worst case that
accumulates well past the ±1 second the same section requires, and the error is
unbounded rather than merely large: a backgrounded app may not tick at all.

Deriving from an anchor makes the error independent of how often, how regularly, or
whether the app looks at the clock. The consequences run through the whole product:

- **Ticks become a rendering concern.** The one-second timer still exists, but only to
  ask the screen to repaint. Dropping ticks costs a stale frame, not a wrong session.
- **Completion is noticed rather than fired.** A session is over because the clock says
  so at the moment someone asks, not because a callback ran. This is what lets ticket 06
  finish a session that elapsed while the app was suspended, and ticket 05 restore one
  mid-flight on cold start.
- **Anchors are UTC.** A session must survive the device crossing a timezone or a DST
  boundary while it runs, which local time does not.
- **The clock may go backwards.** A device clock correction can put `now` behind the
  anchor. Elapsed is clamped at zero rather than going negative; a corrected clock makes a
  session look longer or shorter, and shorter must not read as negative time remaining.
