# 22 — Reset the garden

> ⚠️ **Amended by the v2.1 decision that the app is free.**
> *Premium entitlement, purchased themes and placed-decor availability survive the
> reset* is now two-thirds true and one-third moot: the theme and the ability to arrange
> survive, and there is no entitlement to survive. `entitlements` is dropped at schema
> version 18, so what a reset leaves alone is the settings row. The four tables it
> clears are unchanged.
> See `docs/adr/0021-the-app-is-free-and-sells-nothing.md` and PRD §3.6.

**What to build:** A user who wants a fresh start can clear everything — plants, sessions, stats — behind a double confirmation that makes the finality unmistakable. Their purchase is not part of what gets cleared.

**Blocked by:** 07, 15

**Status:** done — every criterion is built and covered. Two of the ticket's lines were genuinely ambiguous and both were put to the user rather than guessed; the answers are recorded under **Two questions the ticket left open** and each shaped real code. Nothing here is native, talks to a store or talks to the OS, so nothing is unverified for want of a device — the one gap is that **nobody has seen the two dialogs on a phone**, which is ticket 19's inherited gap and is named under **Verification gaps**. The Dart side is 31 new app tests and none in the domain core: **892 and 384**, against 861 and 384 after ticket 21.

- [x] Reset lives in settings behind two confirmations, the second stating plainly that all plants and stats will be cleared and it cannot be undone (REQ-036) — the second dialog's whole body is REQ-036's sentence in REQ-036's words, and it is the last thing the user reads before the destructive button
- [x] Reset clears plants, sessions, streaks, milestone awards, plot capacity and the local event log, returning the garden to its 12-plot first-run state — four tables in **one transaction**; the streak, the capacity and the awards need no clearing because none of them is stored (see ADR 0019)
- [x] Premium entitlement, purchased themes and placed-decor availability survive the reset — `entitlements` is a table the reset does not name, and the arranging control is still over the empty garden afterwards
- [x] User preferences survive the reset — `settings` is the other table it does not name, onboarding flag included
- [x] Milestones can be earned again from zero after a reset — asserted twice: `awardedMilestones()` is empty at the table, and ten fresh sessions after a reset raise the celebration again through the real app
- [x] Reset is refused, or safely cancels the session first, if one is running — **refused**, and the reasoning for choosing that half is in ADR 0019
- [x] The garden, journal and any live surface all reflect the empty state immediately, with no stale data left on screen — six providers republished by name; the live surface needs nothing, and the reason is structural

## What was built

| Where | What |
|---|---|
| `packages/pomodoro_domain/lib/src/garden/garden_reset.dart` | `GardenReset` — one port, one method, and the paragraph on why it is not four |
| `packages/pomodoro_domain/lib/src/analytics/analytics_event_log.dart` | `clear()` **removed** — see below |
| `lib/src/data/drift_garden_reset.dart` | Four deletes in one transaction, and the two tables it deliberately does not touch |
| `lib/src/data/database_providers.dart` | `gardenResetProvider` — the port, beside the six repositories |
| `lib/src/garden/garden_reset_providers.dart` | `gardenMayBeResetProvider`, `Resetting`, `ResetOutcome`, and the controller that republishes |
| `lib/src/features/settings/reset_garden.dart` | `confirmGardenReset` — REQ-036's two questions, and nothing between them |
| `lib/src/features/settings/settings_screen.dart` | `_ResetSection`, `_ResetDoor` — the bottom of the shipping screen |
| `lib/src/data/database.dart` | Two stale forward references to this ticket, corrected now that it has landed |
| `docs/adr/0019-a-reset-is-one-transaction-over-four-tables.md` | The shape, the two tables left out, and what was rejected |
| `CONTEXT.md` | Two words: **reset** and **fresh start**, under a new *Starting again* heading |

## Two questions the ticket left open

Both were put to the user before any of the reset was written, because either
answer would have been defensible and they lead to materially different code.

**Does the arrangement go?** The clear-list in the second criterion omits decor,
the third criterion mentions it, and the second also promises a *12-plot
first-run state* — which a surviving bench makes impossible, because an item
holds its plot open in `GardenLayout`. **Answer: the arrangement is cleared**,
and the third criterion is read as *the entitlement to place decor survives*.
A premium user re-places their objects into a garden they can still arrange.
This is the one place the reset takes something the user composed rather than
something they accumulated, and it is named as a cost in ADR 0019.

**Refuse, or cancel the session first?** The sixth criterion offers both.
**Answer: refuse.** Cancelling would destroy a second thing behind two
confirmations that were about the first — the dialogs say *your plants and your
stats*, and they do not say *and the session you are twenty minutes into*.

## The four things worth knowing before picking up ticket 23 or 24

**A reset is one transaction, and that is the whole architectural decision.** The
alternative — a `clear()` on each of four ports, called in turn — was rejected
because a half-cleared garden is a state no user could reach by using the app,
and therefore a state nothing else in the app is written to survive: plants
without sessions is forty empty plots, sessions without plants is a user owed
seven awards they have already had, and an arrangement without plants is bare
soil out to plot forty. See ADR 0019.

**`AnalyticsEventLog.clear()` was removed, and that is this ticket's doing.**
Ticket 17 added it against this ticket; this ticket chose a different shape, so
it became a domain-port method with no caller — and worse, a second way to empty
the log *without* emptying anything else. Its two test callers now go through
`DriftGardenReset`, which is what they were describing all along. The one route
to clearing anything is the one that clears all of it.

**Everything the ticket asks to be cleared but nothing stores is cleared by not
being stored.** Streaks, plot capacity, garden level and lifetime totals are
derived by query — PRD §4.3, and the README's line about derived counters
drifting after a reset. This is the ticket that collects on that decision: the
reset does not touch any of them and does not have to.

**The republishing is a list, and a new surface has to join it.**
`GardenResetController._republish` invalidates six providers by name, because
nothing in this app watches a table — nothing else ever empties one. A provider
added later that reads `plants`, `sessions`, `decor` or `analytics_events` and
holds the answer must be added there, or it will go on showing a garden the user
was told was gone. Making every read stream from the database instead would
remove the list and would charge every read in the app for a case that happens a
handful of times in an install's life.

## Two smaller decisions

**The outcome is returned, not published.** `GardenExportController` and
`PurchaseController` both leave their outcome in state for a screen to watch, and
this one does not. The reason is the shell's `IndexedStack`: the settings tab is
kept alive for the life of the app, so an outcome held in state would still be
saying *your garden is empty* an hour and three sessions later, by which time it
is false. `clear()` returns a `ResetOutcome`, the caller says it once in a snack
bar, and the message belongs to the tap. It also means nothing touches `ref`
after the two dialogs have been awaited.

**Two dialogs rather than one with a checkbox.** The requirement is a double
confirmation, and two is what makes the second one answerable on its own — a
checkbox is something a finger already on its way to a button skips over. Asking
somebody to type RESET was rejected as a puzzle rather than a warning; what is
being protected is a garden, not a production database.

## Verification gaps

- **Nobody has seen the two dialogs on a device.** Ticket 19's gap inherited —
  this machine has no phone and no emulator. What is asserted is that both are
  there, that the second one carries REQ-036's sentence, that neither route out
  of either clears anything, and that the destructive button takes the theme's
  error role rather than a red of its own. What none of that says is whether the
  pair *feels* like two questions rather than one dialog shown twice.
- **The failure path is staged, not observed.** `_UnclearableGarden` throws from
  the port, which proves the message, the report and that nothing was removed. A
  transaction that fails *partway* through four deletes is SQLite's business and
  is not exercised here; the guarantee rests on `AppDatabase.transaction`.
- **No analytics event, deliberately.** §7.1's table has no `garden_reset`, and
  the log is one of the four things being cleared — so an event recorded here
  would be the single row in a log the user had just emptied. If resets turn out
  to be worth measuring, it is a new `AnalyticsEventName` member and one call
  site in `GardenResetController`.
- **The live surface criterion is satisfied structurally rather than by a
  scenario.** REQ-033's surface only ever shows a session in flight, and a reset
  is refused while there is one, so there is no state in which a lock screen
  could be counting down to a session whose garden has just been cleared. The
  test asserts the surface is down; it cannot assert a case that does not exist.
- **Pre-existing, still open:** `lib/src/data/database.dart` cites "ADR 0014" for
  ticket 17's decision not to backfill the event log, and no ADR 0014 exists.
  This ticket's ADR is 0019 rather than filling the gap, for the reason tickets
  18 to 21 gave when they chose 0015 to 0018.
