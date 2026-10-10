# A day in the journal is the local day a session was anchored in

The botanical journal counts days: sessions this week, a grid of the month, a streak of
consecutive days. Every one of those needs an answer to a question the rest of this app has
been able to avoid since ADR 0001 — **which day does a session belong to?**

The rule is one sentence:

> A session belongs to the **local calendar day its anchor fell in**, whatever time it
> finished and wherever the device has been since.

A session started at 23:50 on Monday and finished at 00:20 on Tuesday is a Monday session.
So is one started at 23:50 and paused until Tuesday lunchtime.

## Why the anchor and not the ending

Three reasons, in the order they matter.

**It is the day the user remembers.** Somebody who sat down at ten to midnight worked on
Monday evening. A journal that filed that under Tuesday would be telling them something
they would have to translate back.

**The garden already says so.** `CONTEXT.md`: *"a plant's date is the day its seed went in
— its session's anchor — not the day the session finished."* A journal that dated the same
session differently from the plant it grew would put a plant on the garden's Monday and a
session on the journal's Tuesday, and nothing in the app would be able to say which was
right.

**It is the only rule that is stable.** An anchor is written when the session starts and
never moves. An ending moves: a session can be paused for an hour, and REQ-011's paused
time pushes the end past midnight without the user doing anything. A rule keyed to the
ending would silently re-file a session because somebody took a phone call.

The alternative that is not obviously wrong — **splitting a session across the boundary,
twenty minutes to Monday and ten to Tuesday** — was rejected because it makes every count
fractional. "You completed 0.7 sessions on Tuesday" is not a sentence a journal can say,
and the plant that session grew cannot be split at all.

## Weeks start where the locale says

A week starts on Monday in Berlin, Sunday in Chicago and Saturday in Cairo, and all three
are right. The app reads `MaterialLocalizations.firstDayOfWeekIndex` and hands it to
`DayRange.week`; nothing in the domain or the database has an opinion.

The conversion between Material's convention (0 = Sunday) and Dart's (`DateTime.monday` =
1) happens in exactly one function, `firstDayOfWeekIn(context)`, because a zero that means
Sunday is a footgun to pass around. `journalProvider` is a family keyed by the result, so
two locales reading the same history are two reads and not one stale answer.

## Local time, in an app that is otherwise UTC

ADR 0001 anchors a session to a UTC instant so that a device changing zone cannot move a
countdown. The journal wants the opposite, for the same reason `seasonProvider` does: **a
day is what the user's own calendar said.** `todayProvider` and the season are the only two
places in this app that call `toLocal()`.

Two halves of the machinery follow from that, and they are split deliberately:

- **Dart decides where a range begins and ends.** `DayRange.from` and `DayRange.until` are
  local midnights converted to UTC instants, so a week containing a daylight-saving change
  really is twenty-three or twenty-five hours longer than the sum of its days. A range as a
  pair of instants is also a seek down an index, where "the local day of this row is
  between these two" would be a function evaluated against every row in the table.
- **SQLite decides which day a row is in.** The grouped queries — the heatmap and the
  streak's days — use `date(started_at, 'unixepoch', 'localtime')`, because a group *is* a
  day and there is nothing to seek. SQLite's `localtime` reads the platform's own time-zone
  database, which is the one `DateTime.toLocal()` reads, so the two cannot disagree about
  where a boundary is.

`CalendarDay` is what carries the answer between them. It holds a date and no time, its
arithmetic is done on UTC calendar dates so a clock change cannot round a day count down,
and it writes itself as `YYYY-MM-DD` — which is exactly the string SQLite groups by, and
which sorts as the calendar does.

## What this costs

**A device that changes time zone re-files history.** Fly from Berlin to Chicago and a
session anchored at 00:30 Berlin time moves to the previous day, because it *was* the
previous day where the user now is. Nothing is lost and no count changes size; a day
boundary is simply somewhere else. The alternative — storing the offset a session was
recorded in and filing it forever by that — would mean a journal whose "today" was in three
different time zones at once.

**A streak is generous at both ends of a day, by design.** REQ-029 counts consecutive days
with a completed session, and `Streak` keeps a streak standing until a *whole* day has
passed with nothing in it: a user who has not sat down yet today still has yesterday's
streak, all of it, until midnight. A day that is not over is not a day that was missed.

## Consequences

- `sessions` gains an index on `(completed, started_at)` and `plants` one on `planted_at`
  (schema version 12, a migration that adds no column and touches no row). The journal's
  range queries become seeks and the streak's `GROUP BY` becomes a covering-index scan —
  see `test/features/journal/journal_performance_test.dart`, which asserts the query plans
  rather than only the milliseconds.
- `todayProvider` holds a timer aimed at the next local midnight, capped at an hour, so a
  journal left open overnight turns over instead of showing yesterday's week. Same shape,
  and same reasoning about corrected clocks, as `GardenSeason`.
- Nothing is stored. There is no `day` column, no streak counter and no cached total; the
  journal is six aggregate queries over the two tables the app already keeps, which is what
  makes it agree with the garden after a restore, an export or ticket 22's reset.
