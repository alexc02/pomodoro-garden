import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';

import '../support/announcement_fakes.dart';
import '../support/app_harness.dart';

/// PRD §4.4, ticket 24: **timer accuracy within ±1 second across a real
/// 120-minute backgrounded session on both platforms.**
///
/// The domain already owns half of this. `session_machine_test.dart` walks a
/// two-hour session through six thousand irregular polls and holds the error
/// under a second at every one of them, which is the arithmetic. What that test
/// cannot say is what happens when *nothing polls at all* — when the app is
/// suspended for two hours, gets no frames, runs no code, and the only two
/// things that carry the session across are a row in SQLite and an alarm the OS
/// is holding. That is this file.
///
/// **Why there is nothing here to drift.** ADR 0001: elapsed time is derived
/// from a wall-clock anchor, never accumulated from ticks. A session is a
/// `startedAt` and a `plannedDuration`; *remaining* is subtraction. There is no
/// counter to fall behind, so a session that is not looked at for two hours is
/// exactly as accurate as one watched the whole way — and the assertions below
/// are exact rather than tolerant, because the design admits no error to
/// tolerate. The ±1 second in §4.4 is the budget; what is asserted is zero.
///
/// **What this still cannot say**, and it is the whole of ticket 24's gap here:
/// that the *device's* clock is the clock this app is handed, and that iOS and
/// Android deliver the alarm when they said they would. A phone that sleeps
/// through its own alarm, or an OEM battery manager that defers it by four
/// minutes, is a failure this suite is structurally unable to see —
/// `docs/battery-baseline.md` has the Doze procedure for provoking it.

/// A phone-sized window.
const Size _window = Size(400, 800);

/// PRD §4.4's number, and the longest session REQ-002 offers.
const Duration _twoHours = Duration(minutes: 120);

/// What the ring says is left, parsed back out of `MM:SS`.
///
/// Parsed here rather than compared against `formatCountdown`: a test that
/// formatted its expectation with the app's own formatter would agree with the
/// app about a bug in the formatter. The minutes field is not wrapped into
/// hours — a two-hour session counts down from `120:00` — which is why this is
/// two fields and not three.
Duration _remainingOnScreen(WidgetTester tester) {
  final digits = RegExp(r'^(\d+):(\d{2})$');

  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final match = digits.firstMatch(text.data ?? '');
    if (match == null) continue;
    return Duration(
      minutes: int.parse(match.group(1)!),
      seconds: int.parse(match.group(2)!),
    );
  }

  fail('nothing on the timer screen looked like a countdown');
}

void main() {
  late AppDatabase database;
  late FixedClock clock;
  late FakeSessionNotifications notifications;

  final anchor = DateTime.utc(2026, 8, 28, 9, 41);

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
    clock = FixedClock(anchor);
    notifications = FakeSessionNotifications();
  });

  Future<void> launch(WidgetTester tester) => pumpApp(
        tester,
        database: database,
        clock: clock,
        notifications: notifications,
        settings: GardenSettings.defaults.withSessionLength(_twoHours),
        surface: _window,
      );

  group('a two-hour session nobody watches', () {
    testWidgets('ends at the instant it was always going to end at',
        (tester) async {
      await launch(tester);
      await startSession(tester);

      final startedAt = clock.now();

      // The app goes away, and *no time is pumped*: the engine is suspended, so
      // there are no frames, no timers and no Dart running at all. Only the
      // clock moves, which is what a phone in a pocket for two hours is.
      await sendToBackground(tester);
      clock.advance(_twoHours);
      await bringToForeground(tester);
      await settle(tester);

      final session =
          (await DriftSessionRepository(database).completedSessions()).single;

      expect(session.startedAt, startedAt);
      expect(session.endedAt, startedAt.add(_twoHours),
          reason: 'the end is the anchor plus the plan, to the millisecond');
      expect(session.endedAt!.difference(session.startedAt), _twoHours);
    });

    testWidgets('and the alarm was set for that instant before it left',
        (tester) async {
      // The other half of the guarantee, and the half that actually reaches the
      // user: on both platforms what announces the end of a backgrounded
      // session is a notice the OS is holding, scheduled once, at an absolute
      // instant. If this is off by a second, the session is off by a second
      // however exact the arithmetic behind it.
      await launch(tester);
      await startSession(tester);

      final startedAt = clock.now();
      await sendToBackground(tester);

      expect(notifications.pending, isNotNull);
      expect(notifications.pending!.at, startedAt.add(_twoHours));
    });

    testWidgets('survives being killed outright halfway through',
        (tester) async {
      // The harder case: not suspended but *gone*. Android reclaiming the
      // process is the ordinary way a two-hour session ends up with nothing in
      // memory, and the row is what the next launch reads.
      await launch(tester);
      await startSession(tester);
      final startedAt = clock.now();

      clock.advance(const Duration(minutes: 61));
      await killApp(tester);

      clock.advance(const Duration(minutes: 59));
      await launch(tester);
      await settle(tester);

      final session =
          (await DriftSessionRepository(database).completedSessions()).single;
      expect(session.endedAt, startedAt.add(_twoHours));
    });
  });

  group('the clock the session is measured by', () {
    testWidgets('does not accumulate error when it is watched the whole way',
        (tester) async {
      // The opposite extreme from the tests above, and the case a tick-counting
      // implementation fails: the session is in the foreground for its whole
      // two hours, rebuilding the countdown, and every step is a real frame
      // rather than a jump of the clock.
      //
      // The step is 7.3 seconds — deliberately not a whole number of seconds
      // and not a multiple of a frame, so the polls land all over each second
      // instead of in step with it. That is what would expose a countdown that
      // rounded, floored or accumulated its way through the session.
      await launch(tester);
      await startSession(tester);
      final startedAt = clock.now();

      const step = Duration(milliseconds: 7300);
      var elapsed = Duration.zero;
      var polls = 0;

      while (elapsed < _twoHours) {
        final next = elapsed + step <= _twoHours ? step : _twoHours - elapsed;
        elapsed += next;
        polls++;
        await advance(tester, clock, next);

        // Read back off the screen, not out of the machine: what §4.4 budgets
        // is what the user is looking at, and the ±1 second is measured
        // against it here rather than against an internal number.
        final shown = _remainingOnScreen(tester);
        final truth = _twoHours - elapsed;
        expect(
          (shown - truth).abs(),
          lessThanOrEqualTo(const Duration(seconds: 1)),
          reason: 'the countdown read $shown with $truth left, after $elapsed',
        );
      }

      expect(polls, greaterThan(900), reason: 'a realistic number of frames');

      final session =
          (await DriftSessionRepository(database).completedSessions()).single;
      expect(session.endedAt, startedAt.add(_twoHours),
          reason: 'nine hundred frames did not move the end by a millisecond, '
              'because none of them was what decided it');
    });
  });
}
