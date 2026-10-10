# 15 — Botanical journal

**What to build:** The user opens the journal tab and sees, in a form that feels like a pressed-flower notebook rather than an analytics dashboard: what they did this week, a month of days coloured by how much they focused, and the satisfying lifetime totals. When they miss days, the app says their garden rested — never that they broke anything.

**Blocked by:** 07

**Status:** done — every criterion is built and covered. The Dart side is 48 new app tests and 48 in the domain core: **591 and 321**, against 543 and 273 after ticket 14, with `flutter analyze --fatal-infos` clean. Two things are written up below rather than left to be discovered: the **day a session belongs to** is now a decided rule with an ADR behind it (`docs/adr/0012-…`), and the **verification gap is a time-zone gap** — this box runs in UTC, so nothing in the suite exercises a device whose clock is offset from it or crosses a daylight-saving boundary.

- [x] Weekly card: sessions this week, total focus time, plants grown, current streak (REQ-026)
- [x] Monthly heatmap: a calendar grid where green intensity reflects sessions that day and empty days read as bare soil, not as failure (REQ-027)
- [x] Lifetime card: total sessions, total focus hours, total plants, garden level, bonus plants earned (REQ-028)
- [x] Streak counts consecutive days with at least one completed session; a broken streak is described gently — "your garden rested for 2 days" — with no guilt language anywhere on the screen (REQ-029)
- [x] Week and day boundaries respect the device timezone and locale's first day of week; a session started before midnight and finished after it is attributed consistently and the rule is documented
- [x] Aggregates are computed by query rather than by loading every session into memory, and stay responsive with several years of history
- [x] Empty state for a brand-new user is inviting rather than a screen of zeroes
- [x] Paper-texture, handwritten-header aesthetic per REQ-025, in light and dark mode

## What was built

| Where | What |
|---|---|
| `packages/pomodoro_domain/lib/src/journal/calendar_day.dart` | `CalendarDay` — a date with no time in it, and the arithmetic that stays right on a 23-hour day |
| `…/journal/day_range.dart` | `DayRange.week` (from the locale's first day) and `DayRange.month`, each both a list of days and a half-open pair of instants |
| `…/journal/streak.dart` | `Streak` — REQ-029's count, `restedDays`, and no notion of a record to have lost |
| `…/journal/journal.dart` | `SessionTally`, `PlantTally`, `JournalWeek`, `JournalMonth`, `JournalLifetime`, `Journal` — every figure on the page, as values |
| `…/journal/journal_repository.dart` | The port, and the rule stated where an implementation has to read it: no method here may be implemented by folding rows in Dart |
| `…/garden/garden_plot.dart` | `GardenPlots.levelAfter` and `maximumLevel` — REQ-028's garden level, derived from REQ-018's own constants |
| `lib/src/data/drift_journal_repository.dart` | The six aggregates, in SQL: `COUNT`, `SUM`, and `GROUP BY date(…, 'localtime')` |
| `lib/src/data/database.dart` | Schema 12: an index on `sessions (completed, started_at)` and one on `plants (planted_at)`. No column, no row touched |
| `lib/src/journal/journal_providers.dart` | `todayProvider` (turns at local midnight) and `journalProvider` — a family keyed by the locale's first day of week, six queries run together |
| `lib/src/features/journal/journal_screen.dart` | The tab: three cards, the streak line, the empty page, and the words |
| `lib/src/features/journal/journal_heatmap.dart` | REQ-027's grid, `heatmapShade`, and the one sentence it is read out as |
| `lib/src/features/journal/journal_paper.dart` | REQ-025's paper: a wash and a bounded scatter of fibres, drawn from the theme |
| `lib/src/design/typography.dart` | `journalHeading` — §5.1's handwritten face, in the second and last place it is allowed |
| `lib/src/session/session_providers.dart`, `lib/src/garden/milestone_providers.dart` | Two lines: a completing session and a landing award invalidate the journal |
| `lib/src/shell/placeholder_screen.dart` | **Deleted.** The journal was the last tab standing behind it |
| `docs/adr/0012-a-day-in-the-journal-is-the-day-a-session-was-anchored.md` | Which day a session belongs to, and the two halves of the machinery that agree about it |
| `CONTEXT.md` | The eight words this ticket introduced: journal, calendar day, anchored to a day, week, streak, rested, garden level, heatmap |

## The one thing worth knowing before picking up a dependent ticket

**Nothing on this page is stored, and nothing counts up.** The journal is six aggregate
queries over the `sessions` and `plants` tables the app already keeps — there is no streak
counter, no lifetime total, no cached "days tended", and no column added anywhere. That is
the ticket README's "derived counters" decision honoured to the letter, and it is what
tickets 21 and 22 inherit: **an export reads the same two tables, and a reset deletes rows
and is done.** Neither has a second copy of the truth to keep in step, and a journal opened
after either agrees with the garden next to it by construction.

The seam is `JournalRepository`, and its contract is a shape rather than a signature: *no
method on it may be implemented by reading the rows and folding them in Dart.* The one
method that returns objects — `plantsIn` — is bounded by a week, because the weekly card
draws those plants rather than counting them.

## Three decisions worth reading before disagreeing with them

**A session belongs to the local day it was *anchored* in.** Ten to midnight on Monday,
finishing twenty past on Tuesday, is a Monday session — the evening the user remembers
working, and the same day the plant it grew is dated (`CONTEXT.md` already said so about
plants; this makes the journal agree). The rejected alternative that is not obviously wrong
is splitting the session across the boundary, and it was rejected because it makes every
count fractional and cannot split the plant at all. ADR 0012 has the rest, including what
happens when a device changes time zone: history re-files itself, because a day boundary is
now somewhere else, and no count changes size.

**Dart decides where a range starts; SQLite decides which day a row is in.** The week and
month queries filter on a pair of UTC instants derived from local midnights — DST-safe, and
a seek down an index. The heatmap and the streak group by
`date(started_at, 'unixepoch', 'localtime')`, because a day is what they group *by* and
there is nothing to seek. Both read the device's own time-zone database, which is the one
`DateTime.toLocal()` reads.

**The tone is enforced by a test that reads the whole page, not by a careful sentence.**
`test/features/journal/journal_screen_test.dart` renders the screen at its most vulnerable
moment — a five-day streak, then forty days off — and asserts that no word on it, from any
`Text` or any semantics label, contains *broke, broken, fail, missed, lost, streak, again,
should, didn't* or *behind*. The screen has no "longest streak" to fall short of, because a
number the app keeps is a number it can hold over somebody. What it says is
`Your garden rested for 40 days.`

## What "computed by query" is asserted as, and not merely measured

`test/features/journal/journal_performance_test.dart` seeds **four years at three sessions
a day — 4,380 sessions and as many plants** — and then does two things. It times all six
reads — budget 150ms each; five of them are under a millisecond here and the streak's
distinct days, the only one with no range to narrow it, is about 20ms — and, because a
workstation would run the *wrong* implementation fast enough to pass a stopwatch, it also
asserts the **query plans**:

| Query | Plan |
|---|---|
| The week's count and sum | `SEARCH sessions USING INDEX sessions_completed_started_at (completed=? AND started_at>? AND started_at<?)` |
| Every day with a session (the streak) | `SEARCH sessions USING COVERING INDEX sessions_completed_started_at (completed=?)` |
| The week's plants | `SEARCH plants USING INDEX plants_planted_at (planted_at>? AND planted_at<?)` |

The streak's is the one that matters most: it is the only query with no range to narrow it,
and a covering index means four years of history are answered without the table being opened
at all.

## Two smaller things this ticket changed on its way past

**`PlaceholderScreen` is gone.** Every tab was one after ticket 01; the timer took its own
in 02, settings in 03, the garden in 07, and the journal was the last. `test/shell/
app_shell_test.dart` now asserts the *absence* — no tab anywhere in the shell says "Arrives
in ticket N" — and its per-tab-state test preserves a scroll position on the journal's own
list instead of the placeholder's.

**The handwritten face has a second sanctioned use.** `GardenTypography.botanicalLabel`'s
doc said it applied to plant names *alone*; REQ-025 asks for handwritten headers on this
screen by name, so `journalHeading` joins it and the doc on both now says the pair is the
whole of §5.1's handwriting. `test/design/typography_test.dart` asserts it is off the UI
family and set larger than a plant's label.

## The verification gap

**This is a time-zone gap, and it is the only one.** Nothing here is native, nothing makes
a sound and nothing talks to the OS, so a workstation can witness all of the behaviour —
except the one input the behaviour is keyed to. The machine running the suite is in UTC, so:

- Every test that involves a day boundary writes its fixtures in **local** time
  (`DateTime(2026, 8, 11, 23, 50).toUtc()`), which means the assertions would be the same
  questions in Auckland or Chicago. What they cannot prove is that the answers are, because
  here local *is* UTC.
- **`date(…, 'localtime')` is SQLite reading the platform's time-zone database**, and
  `DateTime.toLocal()` is Dart reading it. On a device they are the same database — Bionic's
  on Android, `/etc/localtime` on iOS — and on this box they are both UTC, so the suite
  cannot tell a build where they agree from one where they would not. Checking it needs a
  phone (or a suite run under `TZ=`, which does not reach Dart's already-initialised zone).
- **No test crosses a daylight-saving boundary in a zone that observes one.** The arithmetic
  that has to survive it is zone-independent and is tested directly — `CalendarDay.daysUntil`
  counts 31 days across both a spring-forward and a fall-back date, and `DayRange` derives
  its instants from local midnights rather than by adding 24 hours — but the end-to-end case
  is not reachable here.

Everything else is witnessed: the paper texture, the handwritten headings, the four-band
green ramp, both brightnesses, the empty state, the merged-card semantics, and a session
finishing while the journal tab is open.
