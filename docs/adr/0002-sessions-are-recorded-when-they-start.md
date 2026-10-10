# Sessions are recorded when they start, not when they complete

A row lands in `sessions` the moment the user taps START, with `completed = false` and
`endedAt = null`. Completing the session updates that row rather than inserting one.

Recording only completed sessions would be simpler and would satisfy this ticket alone,
but the running row *is* the record of a session in flight, and two later tickets need it:
ticket 05 restores a session mid-flight after a cold start, and distinguishes a voided
session (force-quit) from a cancelled one — neither is possible if nothing was written
until the end. It is also what PRD §4.3 describes, where `endedAt` is documented as "null
while running".

The consequence to know about: the table holds rows that never completed, so **every query
that counts sessions must filter on `completed`**. Total sessions, garden level, plot
count, streaks and lifetime focus time are all derived by query (§4.3), and each of them
is wrong by the number of abandoned sessions if it forgets the filter.
