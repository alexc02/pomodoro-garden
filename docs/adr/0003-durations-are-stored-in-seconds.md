# Durations are stored in seconds, not minutes

`sessions.durationSeconds`, `pausedSeconds`, and in settings `sessionLengthSeconds` and
`breakLengthSeconds` are all seconds.

The domain uses `Duration`, and minutes can't hold one without rounding. Every length a
user can pick is a whole number of minutes, but a lossy column would have to either round
silently or throw. Seconds just store the value, and a 30-second session during testing
comes back as 30 seconds instead of a minute or zero.

The settings sliders still move in whole minutes. The rounding happens in the control, not
in the column.
