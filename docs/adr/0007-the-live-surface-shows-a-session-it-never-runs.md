# The live surface shows a session it never runs

The Dynamic Island, the lock-screen Live Activity and Android's ongoing notification are
**windows onto a session**. None of them holds a countdown, decides that a session is
over, or is required for one to complete. Turning all of it off changes what the user can
see and nothing else.

## The problem

Ticket 08 asks for a countdown on two lock screens, accurate over a session that may run
for two hours with the app never in the foreground. There are two ways to build that, and
they look similar from the outside:

- **The surface is the session.** Something outside the Flutter engine keeps the time —
  a service ticking, a timer being pushed an update a second — and the app reads it back.
- **The surface is a rendering of the session.** The session is where it has always been:
  a wall-clock anchor and a planned duration (ADR 0001). The surface is handed the instant
  the session ends and draws itself from that.

The first is the obvious one, and every symptom of it arrives late. A user with the
surface disabled finds their session no longer completes. A device that kills the service
loses the session with it. The two platforms drift, because a service and an ActivityKit
activity have different lifetimes and whichever one is "the session" is the one whose
rules the domain quietly acquires.

## The decision

The second. Concretely, three things follow from it and every awkward case in this ticket
is one of them:

**The surface is handed an absolute instant, not a duration.** `SessionSnapshot.dueAt` —
when this session reaches its planned duration — goes across the channel as epoch
milliseconds. `Text(timerInterval:)` on iOS and `Notification.setUsesChronometer` on
Android both count to an absolute instant, rendered by the system. So the countdown on the
lock screen is right for the whole session with nothing of this app awake, and the app
pushes an update only when something it *cannot* derive changes: the plant reaching a new
growth stage, or the user holding or resuming the session. That is about six pushes in
twenty-five minutes rather than fifteen hundred.

**Nothing reads back from the surface.** There is no "what does the notification say the
time is". The app asks the clock, exactly as it did before this ticket existed, and the
surface is told. A surface that could be read would be a second source of truth about
elapsed time, and ADR 0001 exists to say there is one.

**Every method on the port is best-effort.** A denied permission, an OEM that refuses the
service, Live Activities switched off in Settings, no implementation registered at all —
all of them are reported and none of them throws at a caller. The session is anchored and
recorded whether or not any of it works.

## Why `dueAt` is on the snapshot rather than computed by callers

Both the live surface and ticket 06's completion notification need the same instant, and
both had been computing it as `clock.now() + snapshot.remaining`. That is the same number
arrived at by adding a fresh reading of the clock to a subtraction from an older one, so it
slides forward by however long the caller took to ask — which on a lock-screen countdown
is a push a second to redraw something already correct, and on a scheduled alarm is a chime
late by the same amount. The machine can compute it exactly, from the anchor, so it does.

## What this costs

**Android's ongoing notification is not the session's life support, and it looks like it
is.** REQ-011 sells the foreground service as buying reliability iOS gets for free, and it
does — a process in the foreground is far less likely to be killed. But that is a *second*
guarantee under REQ-005's first, and it must not become the first: the app already
survives being killed mid-session, and this ticket did not make that true.

**A held session cannot be drawn by the system.** Neither platform can hold a countdown —
both count against the wall clock — so a paused session shows a static remaining time
instead, pushed once when it is held. That is a real asymmetry in what the surface can do,
and it is why `LiveSession` carries both `endsAt` and `remaining`, and why
`showsTheSameAs` compares whichever of the two the surface is currently drawing. While a
session is held its end instant moves every second and nothing on the surface moves with
it; comparing the end instant there would push once a second for the whole of a pause, to
redraw an unchanged number.

**The end of a session has to be drawn by the surface, not pushed to it — on iOS.** The
app is suspended when it matters, so nothing of ours runs at the instant a session
completes. Android has a service in the foreground and can stop itself: one `postDelayed`
at the due instant, and the notification comes down on its own. iOS has nothing alive, so
the activity is given `staleDate = endsAt` and the widget renders a finished state from
`context.isStale` — "Session complete", a full ring, a mature plant. The activity is ended
for real on the next foreground. It stops *claiming* to be a countdown at the right
instant; it stops *existing* at the next launch, and there is no third option that does
not involve a push server this product does not have.

**iOS cannot advance the growth stage while the app is suspended.** Updating a Live
Activity requires either the app running or a push token, and the app has no backend
(PRD §12: local-only). Android's Dart timers keep running behind a backgrounded app, so
the ongoing notification does advance. A Live Activity therefore shows the stage as of the
moment the user put their phone down until they next open the app — the countdown stays
exact, and the plant stops growing on the lock screen. Worth knowing before anyone
promises otherwise in a store screenshot.

**The surface can be stale for a moment after a force-quit.** `LiveSurfaceKeeper` takes it
down on `detached`, best-effort, during teardown — the same window ADR 0005 describes for
the voiding write. On Android the service dies with the process; on iOS the system ends
Live Activities for an app the user force-quits.

## What this rules out, for later tickets

**Reconciling a force-quit against the Live Activity.** ADR 0005 records the gap this
ticket was expected to close: an iOS app suspended and then swiped away is killed without
`detached`, so its session is restored rather than voided. A Live Activity does end on a
force-quit, so "there is a stored session in flight but no activity" looks like a signal.

It is not one. That state is also what a user who turned REQ-033's switch off has, and what
a user who disabled Live Activities in Settings has, and what a device that refused the
request has. Voiding on it would throw away real sessions to catch a case ADR 0005 already
chose to fail kindly on. The gap stays open, and it stays open on purpose.

## Consequences

- `SessionSnapshot` gains `dueAt`, and `SessionAnnouncer` reads it rather than computing
  its own. One instant, one rule, two things promising the user the same moment.
- `LiveSession.showsTheSameAs` is deliberately *not* `==`: it excludes the remaining time
  and the progress, because those are what the platform redraws for itself. It is the
  judgement "is this worth a channel crossing", written down where it can be tested.
- `settings` gains `liveSurfaceEnabled` (schema 7, REQ-033), defaulting to on — and the
  settings screen says in as many words that turning it off does not stop a session,
  because that is the thing a user would reasonably fear and it is a promise this ADR
  makes.
- Which tab the shell is showing moved from `AppShell`'s `State` to
  `selectedTabProvider`, because the tab bar is no longer the only thing that chooses one.
