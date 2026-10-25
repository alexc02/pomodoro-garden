import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/quiet/quiet_mode.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/quiet_mode_fake.dart';

/// REQ-014's quiet mode, driven the way a user drives it.
///
/// Everything below `QuietMode` is Kotlin or Swift and none of it can run here,
/// so these tests assert the half that is ours, which is also the half every
/// one of the ticket's criteria is about: *when* the phone is asked to go quiet,
/// *when* it is let go again, *how often* it is asked, and — the one that
/// matters more than the rest — every route by which the silence is guaranteed
/// not to outlive the session it belongs to.
void main() {
  late FixedClock clock;
  late FakeQuietMode phone;

  /// Quiet mode as a user has it once they have turned it on: the setting on,
  /// and a phone that will act on it.
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
      // The deadline the platform keeps on its own behalf: the instant the
      // session is due, and not a second the app had to stay alive for.
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
      // A held session is a session the user is still in — they have stepped
      // away from the desk, not out of the hour — and a phone that started
      // ringing the moment they paused would be answering a question they did
      // not ask.
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

      // A running session's due instant is the same number on every tick, so
      // there is nothing to re-arm. Ten minutes of asking again would be six
      // hundred channel crossings to say what was already true.
      expect(phone.asks, hasLength(1));
    });

    testWidgets('asks once while the session is held either', (tester) async {
      // The case the comparison above does not cover: a held session's due
      // instant moves every second, because it ends however long after the user
      // comes back. Comparing on it would ask once a second for the whole of a
      // pause.
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

      // Four minutes later than it was, because the session is. The deadline is
      // the platform's only defence against an app that never comes back, so it
      // has to describe the session as it now stands.
      expect(phone.asks, hasLength(2));
      expect(phone.asks.last, testInstant.add(const Duration(minutes: 29)));
    });

    testWidgets('lets the phone speak during a break', (tester) async {
      // A break is time the user is meant to spend away from the desk and
      // available to whoever wanted them. Silencing it would be the app taking
      // the rest it just offered.
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
      // The default, and the one default in the app that is a rule rather than
      // a preference: nothing decides which of somebody's calls they miss on
      // their behalf.
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
      // iOS, and every platform with nothing registered behind the port. The
      // setting can be on — a user with a phone in each pocket shares one
      // settings row through nothing, but a stored row from another build can
      // say anything — and it still asks for nothing.
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
      // The ticket's third criterion. Notification policy access is revoked in
      // system settings, which the user can only reach by leaving — so the
      // return is the moment the app can find out, and it has to look rather
      // than trust what it was told at launch.
      await launch(tester);
      await startSession(tester);
      expect(phone.quiet, isTrue);

      await sendToBackground(tester);
      phone.reportAccess(QuietModeAccess.denied);
      await bringToForeground(tester);
      await settle(tester);

      // The silence is gone, because it was never really there any more: what
      // this catches is the version of the feature that goes on believing it is
      // working.
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

      // The session that was running while they granted it is silenced there
      // and then, rather than the next one being the first to benefit.
      expect(phone.quiet, isTrue);
    });
  });

  group('quiet never outliving its session', () {
    testWidgets('a force-quit lets the phone speak', (tester) async {
      // The session is voided by `SessionLifecycle` on the same signal. A phone
      // left silent here is silent for a session that no longer exists.
      await launch(tester);
      await startSession(tester);

      await forceQuitApp(tester);

      expect(phone.quiet, isFalse);
    });

    testWidgets('backgrounding does not', (tester) async {
      // REQ-013: backgrounding is not an interruption, and a session in a
      // pocket is the one this feature exists for.
      await launch(tester);
      await startSession(tester);

      await sendToBackground(tester);

      expect(phone.quiet, isTrue);
    });

    testWidgets('a launch with nothing in flight says so, unprompted',
        (tester) async {
      // The failure this catches cannot be seen from inside one run of the app:
      // a process the system killed mid-session leaves a rule switched on, and
      // this launch is the first moment anything of ours can switch it off. A
      // keeper that only spoke when it thought something had changed would
      // believe the phone was already loud and say nothing at all.
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
      // Up to where the session actually ends, which is five minutes closer
      // than it was when it started.
      expect(phone.asks.single, testInstant.add(const Duration(minutes: 25)));
    });

    testWidgets('a session found at launch held is silenced again too',
        (tester) async {
      // The case an initial sync is the only thing that covers: a held
      // session's snapshot does not move on its own, so nothing would ever
      // change to wake a listener up.
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
      // iOS's whole half of REQ-014: the user's Shortcut turns their Focus on
      // and runs the app's App Intent, and this is where that arrives. Without
      // it the recipe would be half a recipe.
      await launch(tester);

      phone.requestSession();
      await settle(tester);

      // Running, and on screen: the app was brought forward by something the
      // user did about a session, so the timer is the tab they asked for — the
      // same judgement a tap on the live session surface makes.
      expect(find.text('Focusing'), findsOneWidget);
    });

    testWidgets('leaves a session already running alone', (tester) async {
      await launch(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));

      phone.requestSession();
      await settle(tester);

      // The same session, five minutes in — not a fresh one over the top of it.
      // An automation that fired twice must not cost the user the session they
      // are sitting in.
      expect(find.text('20:00'), findsOneWidget);
    });

    testWidgets('works on a phone that has nothing to do with quiet mode',
        (tester) async {
      // The intent is the app's half of a recipe the *user* assembles, so it
      // works whether or not they ever wired a Focus into it, and whether or
      // not the quiet-mode setting is on.
      phone.reportAccess(QuietModeAccess.unavailable);
      await launch(tester, settings: GardenSettings.defaults);

      phone.requestSession();
      await settle(tester);

      expect(find.text('Focusing'), findsOneWidget);
    });
  });
}
