# 17 — Local analytics event log

> ⚠️ **Amended by the v2.1 decision that the app is free.**
> `paywall_viewed` and `premium_purchased` were never built here and are now removed
> from §7.1 entirely — the screens that would have emitted them do not exist. Eleven
> event names ship, not thirteen, and `garden_exported` carries no parameter.
> See `docs/adr/0021-the-app-is-free-and-sells-nothing.md` and PRD §3.6.

**What to build:** Every event in PRD §7.1 is recorded — to a local table on the device, behind a port, with a debug screen to inspect it. No SDK, no network, no account. This keeps the §7.2 privacy promise literally true while making §11's KPIs measurable the moment a real sink is ever plugged in.

Wire the events that exist by the time this ticket runs. Later tickets emit their own events as part of their acceptance criteria rather than waiting for a second instrumentation sweep.

**Blocked by:** 06, 07

**Status:** done

- [x] A single typed analytics port with strongly-typed event definitions — no stringly-typed event names or untyped parameter maps at call sites
- [x] Every §7.1 event whose feature already exists is emitted with its specified parameters, including session started / completed / abandoned / paused, plant grown, garden viewed, settings changed and app opened
- [x] Events are written to a local table with a timestamp and are queryable
- [x] A debug-only screen lists recent events with their parameters
- [x] The log is bounded — old events are pruned so it cannot grow without limit
- [x] Writing an event never blocks the UI and never fails a user action if persistence errors
- [x] No third-party SDK is added and no network call is made
- [x] Ticket 22's garden reset clears the event log too

## How it was built

**Two ports, because they have different callers.** `Analytics` is where the app *says*
what happened — one method, no future on it, and a contract that it returns at once and
never throws. `AnalyticsEventLog` is where the events are *kept*, and only three things
talk to it: the debug screen, the app-open check and ticket 22's reset. Every §7.1 call
site in the app goes through the first one, so a real sink later is one provider override
and no re-instrumentation.

**The events are sealed classes, not names and maps.** `AnalyticsEvent` has one final
class per §7.1 row, with that row's parameters as typed fields — a call site writes
`SessionStarted.of(plannedDuration)` and cannot misspell an event, omit a parameter or
put a species where a stage goes. `parameters` exists for the log to store and the debug
screen to show; it is the one edge where the types are flattened, and nothing in the app
builds one by hand.

**No screen announces its own settings change.** `AnalyticsEvent.forSettingsChange`
compares two `GardenSettings` and returns what moved, so the settings screen, the ambience
picker on the timer and onboarding's length step are all instrumented without any of them
knowing the analytics port exists. Adding a setting adds a `SettingKey` and a line there.

**Pruned on the way in, not swept.** Nothing of this app runs in the background — REQ-005
— so a scheduled tidy-up is a tidy-up that never happens. `DriftAnalyticsEventLog` writes
the row and deletes everything below the 500th-newest id in the same transaction, as a
contiguous range over the primary key rather than a sort.

**Recording cannot cost a user anything.** `LocalAnalytics.record` stamps the clock and
hands the write to the event loop; a write that throws reaches `FlutterError.reportError`
and goes no further. `test/analytics/session_events_test.dart` drives a whole session with
an event log that throws on every append, and the session still completes, still plants,
and still says so on screen.

Ten of §7.1's thirteen events are emitted. The three missing ones are deliberate:
`garden_exported` belongs to ticket 21 and `paywall_viewed` / `premium_purchased` to
ticket 18 — each arrives with the feature that can emit it, rather than sitting in the
enum as a name nothing records.

**Viewer:** Settings → **Event log (debug)** → Show the event log. Debug builds only;
documented in `README.md`. New vocabulary — event, analytics, event log, recorded — is in
`CONTEXT.md`.

The last box is what ticket 17 can do for it: `AnalyticsEventLog.clear()` exists, is wired
to the same database as everything else, and is tested. Ticket 22 calls it as part of its
own reset.

**One change outside the analytics code.** `GardenView` timed a visit with a `Stopwatch`,
which no test can advance, so `garden_viewed`'s `time_spent` was a parameter that could
only ever be read in production. It is now two instants from the injected `Clock`, like
every other duration this app records.

Tests: `test/analytics/` — session events (11), settings and ambience events (7), app
open and onboarding (7), garden visits (6), the debug screen (6) and the §7.2 privacy
guard (2) — plus `test/data/analytics_event_log_test.dart` for the table and the domain
core's `analytics_event_test.dart` for the events themselves. `./scripts/check.sh` is
green — 665 app tests and 344 in the domain core.

## Verification gaps

- **A garden visit spanning a device clock correction** records the wrong `time_spent`:
  the visit is two `Clock` instants rather than a `Stopwatch`, which is what makes the
  parameter testable at all. See the note on `_visitBegan` in `garden_view.dart`.
- **A garden visit spanning a backgrounding** counts the time the app was away. The visit
  ends when the tab changes or the view is disposed, and backgrounding is neither.
- **The 500-row cap on a real device over months** is asserted by writing 501 rows in a
  test, not by living with the table — what that leaves unproven is the table's size on
  disk after a year of ordinary use, which no test here measures.
