# Sessions are recorded when they start, not when they complete

A row goes into `sessions` as soon as the user taps START, with `endedAt = null`.
Finishing the session updates that row instead of inserting a new one.

Only writing completed sessions would be simpler, but the open row is what makes it
possible to restore a session after a cold start, and to tell a force-quit session apart
from a cancelled one (see ADR 0004).

The catch: the table contains sessions that never finished, so any query that counts
sessions (totals, garden level, plot count, streaks, lifetime focus time) has to filter
on the outcome.
