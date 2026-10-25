# pomodoro_domain

The rules of Pip Garden, in pure Dart: the focus-session state machine,
the growth model, plot placement and milestones.

## The one rule

**Nothing in `lib/` may import Flutter.** No `package:flutter/*`, no `dart:ui`,
no widgets, no `BuildContext`, no `DateTime.now()` reached for directly.

The point is not architectural tidiness. It is that the interesting logic in
this app is time-dependent — a 25-minute session that has to survive the app
being backgrounded, the device changing timezone, and the user coming back four
hours later. Logic like that is only testable if a test can control the clock
and run the rules without a widget binding or a pumped frame. Keeping Flutter
out is what buys that.

Time is read through [`Clock`](lib/src/time/clock.dart). Production injects
`SystemClock`; tests use `FixedClock` and move it by hand.

## How the rule is enforced

Two independent checks, both run by `./scripts/check.sh`:

1. **The analyzer.** This package declares no `flutter` dependency, and
   `depend_on_referenced_packages` is promoted to an error in
   `analysis_options.yaml`, so a Flutter import fails `flutter analyze`.
2. **[A test](test/domain_has_no_flutter_imports_test.dart).** Scans `lib/` for
   forbidden imports and asserts the pubspec has not grown a `flutter`
   dependency. It exists alongside the lint because it fails with a message
   that explains *why*, and because it catches the case where someone "fixes"
   the lint by adding the dependency.

Both were verified to go red on a real violation, not just green on a clean
tree.

## Adding to this package

Dependencies must be pure Dart. If something needs Flutter, it is not domain
logic — it belongs in the app package, usually behind a port declared here and
implemented there.

## Tests

```sh
cd packages/pomodoro_domain && dart test
```

Run under the Dart VM, not `flutter test`: faster, and it would fail outright if
this package ever needed the Flutter engine.
