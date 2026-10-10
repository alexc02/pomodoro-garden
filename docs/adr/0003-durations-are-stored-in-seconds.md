# Durations are stored in seconds, not minutes

The `sessions` table stores `durationSeconds`. PRD §4.3 calls the column
`durationMinutes`; this is a deliberate departure, and the PRD should be corrected to
match — per `issues/README.md`, where the two disagree the ticket wins.

The domain's planned duration is a `Duration`, and minutes cannot store one without
losing information. Every duration the *user* can pick is a whole number of minutes
(REQ-006: 5–120), so on the surface the two are equivalent — but the mapping between them
is not total, and a lossy mapping at the persistence boundary has to either round
silently or throw, both of which are worse than a column that simply holds the value.
Seconds also match `pausedSeconds`, which §4.3 already specifies in seconds, so the two
duration columns are now in the same unit and cannot be confused for each other.

The practical consequence is that a short session — a 30-second one during QA, or anything
sub-minute a later ticket wants — records and reloads correctly instead of arriving back
as a minute, or as zero.

Ticket 03's `settings` table follows the same rule: `sessionLengthSeconds` and
`breakLengthSeconds`, where PRD §4.3 names `sessionLengthMinutes` and `breakLengthMinutes`.
The settings *sliders* move in whole minutes, because REQ-030 says so — but the rounding
belongs at the control, not at the column, and keeping the two duration columns in one unit
keeps the mapping in `DriftSettingsRepository` from being the place a unit gets confused.
