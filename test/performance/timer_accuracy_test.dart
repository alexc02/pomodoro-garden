import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';

import '../support/announcement_fakes.dart';
import '../support/app_harness.dart';

// Timer accuracy within 1 s over a 120-minute backgrounded session. The
// domain tests cover the arithmetic over many polls; this covers the case where
// nothing polls at all and only the SQLite row and the OS alarm carry the
// session.
//
// Elapsed time comes from a wall-clock anchor, not ticks (ADR 0001), so the
// assertions are exact. What this can't see is the device clock or the OS
// delivering the alarm late (Doze, OEM battery managers).

const Size _window = Size(400, 800);

/// The longest session length offered.
const Duration _twoHours = Duration(minutes: 120);

/// Remaining time parsed off the ring's `MM:SS`. Parsed by hand rather than
/// with `formatCountdown` so a formatter bug can't hide. Minutes don't wrap
/// into hours (`120:00`).
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

      // No time is pumped: the engine is suspended, only the clock moves.
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
      // The OS-held notice is what actually tells the user, so its instant has
      // to be exact too.
      await launch(tester);
      await startSession(tester);

      final startedAt = clock.now();
      await sendToBackground(tester);

      expect(notifications.pending, isNotNull);
      expect(notifications.pending!.at, startedAt.add(_twoHours));
    });

    testWidgets('survives being killed outright halfway through',
        (tester) async {
      // Not suspended but gone, e.g. Android reclaiming the process.
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
      // The case a tick-counting implementation fails: foreground the whole two
      // hours. 7.3 s steps so polls land all over each second and expose any
      // rounding or accumulation.
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

        // Read off the screen, since that's what the user sees.
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
          reason: 'the frames should not move the end at all');
    });
  });
}
