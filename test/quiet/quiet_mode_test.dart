import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/quiet/quiet_mode.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/quiet_mode_fake.dart';

/// Quiet mode, driven through the app. The native side can't run here, so this
/// covers when the phone is asked to go quiet, when it's released, how often
/// it's asked, and every route that makes sure the silence ends with the
/// session.
void main() {
  late FixedClock clock;
  late FakeQuietMode phone;

  /// Setting on, and a phone that can act on it.
  final asked = GardenSettings.defaults.withQuietMode(enabled: true);

  setUp(() {
    clock = FixedClock(testInstant);
    phone = FakeQuietMode(reports: QuietModeAccess.granted);
  });

  Future<void> launch(
    WidgetTester tester, {
    GardenSettings? settings,
    AppDatabase? database,
  }) =>
      pumpApp(
        tester,
        clock: clock,
        quietMode: phone,
        database: database,
        settings: settings ?? asked,
      );

  group('a session with quiet mode on', () {
    testWidgets('silences the phone when it starts', (tester) async {
      await launch(tester);
      expect(phone.quiet, isFalse);

      await startSession(tester);

      expect(phone.quiet, isTrue);
      // The deadline the platform keeps itself: the session's due instant.
      expect(phone.asks.single, testInstant.add(const Duration(minutes: 25)));
    });

    testWidgets('lets it make noise again when the session completes',
        (tester) async {
      await launch(tester);
      await startSession(tester);

      await advance(tester, clock, const Duration(minutes: 25));

      expect(find.text('Session complete'), findsOneWidget);
      expect(phone.quiet, isFalse);
    });

    testWidgets('lets it make noise again when the session is cancelled',
        (tester) async {
      await launch(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));

      await cancelSession(tester, confirm: true);

      expect(phone.quiet, isFalse);
    });

    testWidgets('leaves it quiet when the user changes their mind about '
        'cancelling', (tester) async {
      await launch(tester);
      await startSession(tester);

      await cancelSession(tester, confirm: false);

      expect(phone.quiet, isTrue);
    });

    testWidgets('keeps it quiet while the session is held', (tester) async {
      // A held session is still in progress; the phone shouldn't start ringing
      // on pause.
      await launch(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 10));

      await pauseSession(tester);
      await advance(tester, clock, const Duration(minutes: 4));

      expect(phone.quiet, isTrue);
    });

    testWidgets('asks once, not once a second', (tester) async {
      await launch(tester);
      await startSession(tester);

      await advance(tester, clock, const Duration(minutes: 10));

      // A running session's due instant doesn't change per tick, so nothing to
      // re-arm.
      expect(phone.asks, hasLength(1));
    });

    testWidgets('asks once while the session is held either', (tester) async {
      // A held session's due instant moves every second, so comparing on it
      // would re-ask for the whole pause.
      await launch(tester);
      await startSession(tester);
      await pauseSession(tester);

      await advance(tester, clock, const Duration(minutes: 4));

      expect(phone.asks, hasLength(1));
    });

    testWidgets('moves the deadline when a held session is resumed',
        (tester) async {
      await launch(tester);
      await startSession(tester);
      await pauseSession(tester);
      await advance(tester, clock, const Duration(minutes: 4));

      await resumeSession(tester);

      // Four minutes later, like the session. The deadline is the fallback if
      // the app never comes back, so it has to be current.
      expect(phone.asks, hasLength(2));
      expect(phone.asks.last, testInstant.add(const Duration(minutes: 29)));
    });

    testWidgets('lets the phone speak during a break', (tester) async {
      // Breaks are for being reachable.
      await launch(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));

      await tester.tap(find.text('Take a 5 min break'));
      await settle(tester);

      expect(find.text('On a break'), findsOneWidget);
      expect(phone.quiet, isFalse);
    });
  });

  group('what it never does', () {
    testWidgets('silence a phone whose owner did not ask', (tester) async {
      // Off by default: the app never decides which calls someone misses.
      await launch(tester, settings: GardenSettings.defaults);
      await startSession(tester);

      expect(phone.quiet, isFalse);
      expect(phone.asks, isEmpty);
    });

    testWidgets('silence a phone that has not granted the permission',
        (tester) async {
      phone.reportAccess(QuietModeAccess.denied);

      await launch(tester);
      await startSession(tester);

      expect(phone.quiet, isFalse);
      expect(phone.asks, isEmpty);
    });

    testWidgets('ask a phone that cannot do it at all', (tester) async {
      // iOS, or no implementation behind the port. A stored row from another
      // build can say anything; still nothing is asked.
      phone.reportAccess(QuietModeAccess.unavailable);

      await launch(tester);
      await startSession(tester);

      expect(phone.asks, isEmpty);
    });

    testWidgets('carry on when the setting is turned off mid-session',
        (tester) async {
      await launch(tester);
      await startSession(tester);
      expect(phone.quiet, isTrue);

      await tapTab(tester, AppTab.settings);
      await tester.tap(await scrollToSetting(tester, SettingsKeys.quietMode));
      await settle(tester);

      expect(phone.quiet, isFalse);
    });
  });

  group('a permission taken away', () {
    testWidgets('is noticed on the way back into the app', (tester) async {
      // Access is revoked in system settings, so the app has to re-check on the
      // way back in rather than trust launch.
      await launch(tester);
      await startSession(tester);
      expect(phone.quiet, isTrue);

      await sendToBackground(tester);
      phone.reportAccess(QuietModeAccess.denied);
      await bringToForeground(tester);
      await settle(tester);

      // Catches the version that keeps believing it's working.
      expect(phone.quiet, isFalse);
    });

    testWidgets('is granted again the same way', (tester) async {
      phone.reportAccess(QuietModeAccess.denied);
      await launch(tester);
      await startSession(tester);
      expect(phone.quiet, isFalse);

      await sendToBackground(tester);
      phone.reportAccess(QuietModeAccess.granted);
      await bringToForeground(tester);
      await settle(tester);

      // The running session gets silenced right away, not just the next one.
      expect(phone.quiet, isTrue);
    });
  });

  group('quiet never outliving its session', () {
    testWidgets('a force-quit lets the phone speak', (tester) async {
      // `SessionLifecycle` voids the session on the same signal.
      await launch(tester);
      await startSession(tester);

      await forceQuitApp(tester);

      expect(phone.quiet, isFalse);
    });

    testWidgets('backgrounding does not', (tester) async {
      // Backgrounding isn't an interruption, and a phone in a pocket is the
      // main use case.
      await launch(tester);
      await startSession(tester);

      await sendToBackground(tester);

      expect(phone.quiet, isTrue);
    });

    testWidgets('a launch with nothing in flight says so, unprompted',
        (tester) async {
      // A process killed mid-session leaves the rule on, and this launch is the
      // first chance to turn it off. Only speaking up on a change would miss
      // it.
      await launch(tester);

      expect(phone.everAsked, isTrue);
      expect(phone.releases, greaterThan(0));
      expect(phone.quiet, isFalse);
    });

    testWidgets('a session found at launch is silenced again', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);

      await launch(tester, database: database);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await killApp(tester);

      phone = FakeQuietMode(reports: QuietModeAccess.granted);
      await launch(tester, database: database);

      expect(phone.quiet, isTrue);
      // Until the session's real end, five minutes closer than at start.
      expect(phone.asks.single, testInstant.add(const Duration(minutes: 25)));
    });

    testWidgets('a session found at launch held is silenced again too',
        (tester) async {
      // Only the initial sync covers this: a held snapshot never changes on its
      // own.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);

      await launch(tester, database: database);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await pauseSession(tester);
      await killApp(tester);

      phone = FakeQuietMode(reports: QuietModeAccess.granted);
      await launch(tester, database: database);

      expect(phone.quiet, isTrue);
    });
  });

  group('a session asked for from outside the app', () {
    testWidgets('starts one', (tester) async {
      // The iOS route: the user's Shortcut turns on Focus and runs the App
      // Intent, which lands here.
      await launch(tester);

      phone.requestSession();
      await settle(tester);

      // Running and on the timer tab, same as tapping the live surface.
      expect(find.text('Focusing'), findsOneWidget);
    });

    testWidgets('leaves a session already running alone', (tester) async {
      await launch(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));

      phone.requestSession();
      await settle(tester);

      // Same session, five minutes in. A double-fired automation mustn't
      // restart it.
      expect(find.text('20:00'), findsOneWidget);
    });

    testWidgets('works on a phone that has nothing to do with quiet mode',
        (tester) async {
      // Works regardless of Focus setup or the quiet-mode setting.
      phone.reportAccess(QuietModeAccess.unavailable);
      await launch(tester, settings: GardenSettings.defaults);

      phone.requestSession();
      await settle(tester);

      expect(find.text('Focusing'), findsOneWidget);
    });
  });
}
