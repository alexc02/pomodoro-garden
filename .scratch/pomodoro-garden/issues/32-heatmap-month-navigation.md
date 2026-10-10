# 32 — Browse earlier months in the journal heatmap

**What to build:** previous/next arrows on the journal's month heatmap, so the user can look back at earlier months. It opens on the current month, as today, and can never move past it. PRD v2.2 REQ-027. Found by the gap review as an observation: on the 1st of each month the heatmap is almost empty, and there is no way back.

**Blocked by:** nothing.

**Status:** done.

- [x] Previous / next controls beside the month heading; "next" is disabled on the current month
- [x] The month shown is screen state, not a setting: it is not persisted, and the journal opens on the current month on every launch. *It survives switching tabs while the app runs, because the shell keeps every tab alive (`IndexedStack`); that was judged fine, since it is where the user left it*
- [x] The heatmap, its spoken summary and the "days tended" line all describe the month shown
- [x] The week card and the lifetime card are unaffected: they always describe now
- [x] Earlier months come from the existing month query (`DayRange.month`); nothing new is stored
- [x] Going back stops at the month of the first recorded session, or is allowed indefinitely with bare-soil months; decide which and record it here. **Decided: it stops at the month of the first completed session.** Months between that one and now are shown even when bare
- [x] Months are correct across DST changes and year boundaries (December → January); tests cover both. *Year boundaries and short months are covered by domain tests on `CalendarDay.firstOfMonth`. DST cannot move a month: the step works on the local first of the month and reads only its date*
- [x] `flutter analyze --fatal-infos` clean; app and domain suites green

## What was built

| Where | What |
|---|---|
| `packages/pomodoro_domain/lib/src/journal/calendar_day.dart` | `firstOfMonth({monthsLater})`: the first of this month or one before or after it |
| `…/journal/journal.dart` | `Journal.firstTended`: the earliest day with a completed session, or null |
| `lib/src/journal/journal_providers.dart` | `firstTended` filled from the days the journal already reads; `journalMonthProvider`, one month by its first day, read only when the user steps back |
| `lib/src/session/session_providers.dart`, `lib/src/garden/garden_reset_providers.dart`, `lib/src/garden/milestone_providers.dart` | Each place that invalidates the journal now invalidates the past months too. A session anchored late on a month's last day belongs to that month |
| `lib/src/features/journal/journal_screen.dart` | `_MonthCard` keeps how many months back it is showing; arrows beside the heading (`JournalKeys.previousMonth`, `nextMonth`); "that month" wording for past months; a month still loading is drawn as bare soil so the arrows don't jump. `_JournalCard` gained `actions` |
| `packages/pomodoro_domain/test/journal/calendar_day_test.dart` | Four tests for stepping months, across a year and over a short month |
| `test/features/journal/journal_screen_test.dart` | Six widget tests: opens on this month, steps back through a bare month, stops at the first session's month, comes forward again, a user with only this month can't go back, and the week and lifetime cards stay on today |

Suites: 970 app and 392 domain tests pass; analyzer clean.

**Verification gap:** none; nothing here is device-specific.
