# Settings are read once, before the app opens

`SettingsGate` sits between the `MaterialApp` and the shell. It builds nothing below it
until the stored settings have come back from SQLite, so `settingsProvider` — the one
accessor every screen reads a setting through — is a plain synchronous `GardenSettings`
rather than an `AsyncValue` of one.

The alternative is to let every consumer handle a loading state. That is a worse deal than
it looks. It is not only that a dozen screens would each grow a `when(loading: …)` branch;
it is that the sensible-looking thing to put in that branch is the defaults, and the
defaults are wrong. A user whose session length is 50 minutes, who launches the app and
taps START before a single-row select has come back, would get a 25-minute session — and
would get it silently, with a correct-looking countdown, because nothing about the running
session says which length it came from. That bug appears on a cold start on a slow device
and nowhere else, which is to say it appears for users and not in tests.

Holding the app back turns that into an impossibility rather than a race: below the gate
there is no state in which settings are unknown. `settingsProvider` throws if it is read
above the gate, which is the same judgement `GardenColors.of` makes about a widget outside
the theme — a wiring bug should be loud, not silently served with defaults.

The cost is a frame or two at launch. PRD §4.4 budgets 1.5 seconds from launch to the
garden being visible; this spends one indexed select on an already-open connection of it.
What shows during the wait is the app's background and the seedling, held still — no
spinner, because a spinner that flashes for two frames reads as a glitch.

**A settings read that fails does not stop the app.** `SettingsController.build` catches,
reports through `FlutterError.reportError`, and returns the defaults. A database that will
not answer is a broken app rather than a broken setting — sessions live in the same file —
and a user in that state is better served by a timer that runs on 25 minutes than by a
screen that will not open. The same judgement, for the same reason, as the failed session
write in `SessionController._save`.
