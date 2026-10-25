# The app is called Pip Garden

PRD v2.4. The app was called **Pomodoro Garden** and is now called **Pip Garden**. The old
name was too close to apps already in the stores: PomoGarden, Bloomodoro and several
called Focus Garden. A pip is a seed.

## The whole name, identifiers included

The rename was made before the first store upload, with no install anywhere but a
development simulator, so nothing a user owns depended on the old identifiers. It goes
all the way down:

| What | Now |
|---|---|
| The name people read: app label, Live Activity, Shortcuts, Do Not Disturb rule, settings copy, store and privacy drafts, docs | **Pip Garden** |
| Android application ID and Kotlin package | `com.pipgarden.pip_garden` |
| iOS bundle IDs | `com.pipgarden.pipGarden` (and `.LiveSessionWidget`, `.RunnerTests`) |
| The Dart package | `pip_garden` |
| Method channels, intent actions | `pip_garden/…`, `com.pipgarden.pip_garden.…` |
| Deep-link scheme and the Do Not Disturb rule's condition id | `pipgarden://` |
| The database file | `pip_garden.sqlite` |
| The exported picture | `pip-garden.png` |

**This could only be done once.** The application ID and bundle IDs become permanent at
the first upload. The database file, the rule's condition id and the deep-link scheme
would each need a migration once anyone has the app: a new file name opens an empty
garden, and a new condition id leaves the old rule behind in the user's settings.

## What keeps the old word

- `packages/pomodoro_domain`: it models the Pomodoro technique, which is still what the
  app runs.
- `test/data/database_migration_test.dart` seeds a `com.pomodorogarden.premium_unlock`
  row: it stands for data written by an old schema, and the old name is the point.
- Earlier ADRs and the tickets in `.scratch/pip-garden/` were written under the old name
  and keep it in their prose.
