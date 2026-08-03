# pomodoro_domain

Pip Garden's core rules in plain Dart: the session state machine, plant growth, plot
placement, milestones and the journal.

Nothing in `lib/` imports Flutter (no `package:flutter/*`, no `dart:ui`) or calls
`DateTime.now()` directly. Most of the interesting logic depends on time (a session
surviving backgrounding, timezone changes, coming back hours later), and keeping it pure
means tests can drive the clock without a widget binding. Time comes from
[`Clock`](lib/src/time/clock.dart): `SystemClock` in the app, `FixedClock` in tests.

Two things enforce this:

- the package has no `flutter` dependency, and `depend_on_referenced_packages` is an error
  in `analysis_options.yaml`
- [`domain_has_no_flutter_imports_test.dart`](test/domain_has_no_flutter_imports_test.dart)
  scans `lib/` for Flutter imports and checks the pubspec. It also catches someone adding
  the `flutter` dependency to make the lint go away.

If something needs Flutter, it belongs in the app: declare an interface here and implement
it there.

```sh
cd packages/pomodoro_domain && dart test
```
