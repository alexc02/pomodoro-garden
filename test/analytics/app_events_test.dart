import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/features/onboarding/onboarding_steps.dart';

import '../support/app_harness.dart';
import '../support/event_log.dart';

/// PRD §7.1's `app_opened` and `onboarding_completed`: the two events about the
/// app itself rather than about anything the user did inside it.
///
/// Both are driven through a real launch, because both are *about* the launch —
/// `app_opened` reads the gap to the last one out of the log, and
/// `onboarding_completed` is only ever emitted on a first run.
void main() {
  late FixedClock clock;
  late AppDatabase database;

  setUp(() {
    clock = FixedClock(testInstant);
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  /// Launches the app again on the same database, as a relaunch does.
  Future<void> relaunch(WidgetTester tester) async {
    await killApp(tester);
    await pumpApp(tester, clock: clock, database: database);
  }

  group('app_opened', () {
    testWidgets('a first open has no last open and no streak', (tester) async {
      await pumpApp(tester, clock: clock, database: database);
      await settle(tester);

      final event = await theEventNamed(
        database,
        AnalyticsEventName.appOpened,
      );

      expect(event.parameters, {
        // Null rather than zero: the app has never been opened before, which is
        // not the same fact as having been opened today.
        'days_since_last_open': null,
        'streak_days': 0,
      });
    });

    testWidgets('a later open counts the calendar days since the last one',
        (tester) async {
      await pumpApp(tester, clock: clock, database: database);
      await settle(tester);

      clock.advance(const Duration(days: 3));
      await relaunch(tester);

      final opens = await eventsNamed(database, AnalyticsEventName.appOpened);

      expect(opens, hasLength(2));
      expect(opens.last.parameters['days_since_last_open'], 3);
    });

    testWidgets('a session today makes the streak one day', (tester) async {
      await pumpApp(tester, clock: clock, database: database);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      await relaunch(tester);

      expect(
        (await eventsNamed(database, AnalyticsEventName.appOpened))
            .last
            .parameters['streak_days'],
        1,
      );
    });

    testWidgets('coming back from the background is not another open',
        (tester) async {
      // §7.1 is measuring retention, and a user who glances at their phone
      // during a session has opened the app once.
      await pumpApp(tester, clock: clock, database: database);
      await settle(tester);

      await sendToBackground(tester);
      await bringToForeground(tester);
      await settle(tester);

      expect(
        await eventsNamed(database, AnalyticsEventName.appOpened),
        hasLength(1),
      );
    });
  });

  group('onboarding_completed', () {
    testWidgets('a user who goes all the way through records three steps and '
        'how long it took', (tester) async {
      await pumpApp(
        tester,
        clock: clock,
        database: database,
        firstLaunch: true,
      );

      await tester.tap(find.byKey(OnboardingKeys.next));
      await settle(tester);
      clock.advance(const Duration(seconds: 20));
      await tester.tap(find.byKey(OnboardingKeys.next));
      await settle(tester);
      clock.advance(const Duration(seconds: 10));
      await tester.tap(find.byKey(OnboardingKeys.start));
      await settle(tester);

      final event = await theEventNamed(
        database,
        AnalyticsEventName.onboardingCompleted,
      );

      expect(event.parameters, {
        'steps_completed': 3,
        'time_to_first_session_seconds': 30,
      });
    });

    testWidgets('a user who skips records the steps behind them and no time',
        (tester) async {
      // Skipping is still the user having met onboarding, and §7.1's friction is
      // exactly what a user who walked out measures. There is no time to a
      // session because they started none.
      await pumpApp(
        tester,
        clock: clock,
        database: database,
        firstLaunch: true,
      );

      await tester.tap(find.byKey(OnboardingKeys.next));
      await settle(tester);
      await tester.tap(find.byKey(OnboardingKeys.skip));
      await settle(tester);

      final event = await theEventNamed(
        database,
        AnalyticsEventName.onboardingCompleted,
      );

      expect(event.parameters['steps_completed'], 1);
      expect(event.parameters['time_to_first_session_seconds'], isNull);
    });

    testWidgets('a launch that is not the first records nothing',
        (tester) async {
      await pumpApp(tester, clock: clock, database: database);
      await settle(tester);

      expect(
        await eventsNamed(database, AnalyticsEventName.onboardingCompleted),
        isEmpty,
      );
    });
  });
}
