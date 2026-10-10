# 0019 — A reset is one transaction over four tables

**Status:** accepted, ticket 22 · amended by
[ADR 0021](0021-the-app-is-free-and-sells-nothing.md)

> **There is no entitlement to survive a reset any more.** The app is free: the
> `entitlements` table is dropped at schema version 18, so what a reset leaves alone is
> the settings row and nothing else. The four tables it clears, and the one transaction
> it clears them in, are unchanged — as is the fact that the arrangement is among them.

## The question

REQ-036 asks for a garden reset in settings, behind a double confirmation, that
clears all plants and stats and cannot be undone. Ticket 22 spells out what
"stats" reaches — sessions, streaks, milestone awards, plot capacity and the
local event log — and, more usefully, what it does not: the premium entitlement,
the purchased themes, the ability to place decor, and every preference the user
has set.

By this point the app has six tables in one SQLite file and six ports over them.
Nothing in the app has ever deleted a row. So there are two questions, and the
second is the one that matters:

1. Which tables does a reset empty?
2. What shape does the emptying take — a `clear` on each port, or something
   else?

## The decision

**One port, one method, one transaction.** `GardenReset.clear()` empties
`plants`, `sessions`, `decor` and `analytics_events` together, and
`DriftGardenReset` is the whole of the implementation: four `DELETE FROM`s
inside `AppDatabase.transaction`.

The alternative — a `clear()` on `PlantRepository`, `SessionRepository`,
`DecorRepository` and `AnalyticsEventLog`, called in turn by a controller — was
rejected because **a half-cleared garden is worse than an uncleared one**, and
four calls is three chances to stop between them. The three tables answer
questions about each other:

- Capacity is derived from the count of completed sessions, so plants without
  sessions is a garden of forty empty plots and sessions without plants is
  twelve plots holding thirty things.
- The milestones already awarded are read off the plants, so sessions without
  plants is a user owed seven awards they have already had.
- A decor item holds its plot open in `GardenLayout`, so an arrangement that
  outlived the plants is a "fresh start" showing bare soil out to plot forty.

None of those is a state a user could reach by using the app, which means none
of them is a state the rest of the app is written to survive. A transaction is
the only shape in which "reset" is something that either happened or did not.

**`AnalyticsEventLog.clear()` was removed.** It was added by ticket 17 against
this ticket, and this ticket chose a different shape — so it was a method on a
domain port with no caller, and worse, a second way to empty the log *without*
emptying anything else. The one route to clearing anything is now the one that
clears all of it.

**The two tables it does not reach are named in the code, not merely absent.**
`settings` and `entitlements` are in the same database and are untouched. The
comment in `DriftGardenReset` says so, because absence by omission is exactly
the kind of thing a later ticket adds a fifth line under.

That `entitlements` is a table of its own rather than a column on the settings
row (ADR 0015) is why this cost no code at all: there is nothing to filter, and
no `WHERE` clause anybody could get wrong.

**Everything the ticket asks to be cleared but nothing stores is cleared by not
being stored.** Streaks, plot capacity, garden level and lifetime totals are
derived by query (PRD §4.3, and the README's note on derived counters). A reset
does not touch them and does not have to: the rows they are counted from are
gone, so they answer with their first-run values. This is the payoff of that
decision, and ticket 22 is the ticket that collects it.

**A reset is refused while a timer is in flight.** The ticket allows either
refusing or safely cancelling the session first. Refusing, because cancelling
would be destroying a second thing behind two confirmations that were about the
first — the dialogs say *your plants and your stats*, and they do not say *and
the session you are twenty minutes into*. `gardenMayBeResetProvider` closes the
same four phases `paywallMayOpenProvider` closes, and the switch is written out
again rather than shared: one is REQ-041's rule about selling and one is
REQ-036's rule about destroying, and a phase added later deserves an answer from
each on its own terms.

This is also what makes the ticket's last criterion free. The live surface only
ever shows a session in flight, so there is no state in which a lock screen could
be counting down to a session whose garden has just been cleared.

## What it costs

**The republishing is a list somebody has to keep right.** The garden, the
journal and the milestone queue read the cleared tables once and hold the answer;
nothing in the app watches a table, because nothing else in the app ever empties
one. So `GardenResetController._republish` invalidates six providers by name, and
a surface added later that reads plants or sessions has to be added to it. A
surface forgotten there is a surface still showing a garden the user was told was
gone.

Making the providers stream from the database instead would remove the list and
would change every read in the app to pay for a case that happens at most a
handful of times in an install's life.

**The arrangement is cleared, and that is a real loss.** A premium user who
resets loses the composition they made, and CONTEXT.md is otherwise careful that
*what somebody composed is theirs* — nothing takes an arrangement away for want
of an entitlement, and the entitlement is exactly what survives here. It goes
because the second confirmation promises a garden cleared and `GardenLayout` would
otherwise keep the plots the furniture stands in. What survives is the right to
arrange again.

## What was rejected

**Clearing the settings row too.** PRD §4.3 puts `onboardingCompleted` on it, so
a reset that took it would greet a user of two years with a welcome screen. More
broadly: a user asking for a fresh garden has not asked for their session length
back at twenty-five minutes, and "reset the garden" is not "reset the app".

**Recording a `garden_reset` event.** §7.1's table has no such event, and
`AnalyticsEventName` is kept to names with a call site. The sharper reason is
that the log is one of the four things being emptied — so the event would be the
single row in a log the user had just cleared, and the app's only remaining note
of a garden they asked it to forget.

**A single confirmation with a typed word or a checkbox.** The requirement is a
double confirmation, and two dialogs is what makes the second one answerable on
its own. A checkbox is something a finger already on its way to a button skips
over; asking somebody to type RESET is a puzzle rather than a warning, and the
thing being protected is a garden rather than a production database.

**Keeping the outcome as a note under the control.** The settings tab is kept
alive by the shell's `IndexedStack`, so a note bound to controller state would
still be reading *your garden is empty* an hour and three sessions later, by
which time it is false. It is a snack bar, said once, to the person who just did
it.
