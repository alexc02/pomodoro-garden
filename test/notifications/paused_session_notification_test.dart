import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/app.dart';
import 'package:pip_garden/src/notifications/local_session_notifications.dart';
import 'package:pip_garden/src/session/session_providers.dart';

import 'package:pip_garden/src/notifications/session_notifications.dart';

import '../support/announcement_fakes.dart';
import '../support/app_harness.dart';

// Regression for the report: "15 min session. Paused after 5 min. App switch. 10 min later a
// notification said the plant had grown. The session was still paused."
//
// Uses the real SessionAnnouncer and the real LocalSessionNotifications, plus
// the real flutter_local_notifications Dart code. Only the OS side of the
// plugin's method channel is faked (`_FakeNotificationOs`), so the awaits
// between "schedule" and "cancel" are the production ones.

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

/// The OS's list of pending notifications, keyed by id.
final class _FakeNotificationOs {
  final Map<int, ({String title, DateTime at})> pending = {};
  final List<String> log = [];

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'zonedSchedule':
        final args = (call.arguments as Map).cast<String, Object?>();
        final at = DateTime.parse('${args['scheduledDateTime']}Z');
        pending[args['id']! as int] = (title: '${args['title']}', at: at);
        log.add('schedule #${args['id']} @ ${at.toIso8601String()}');
        return null;
      case 'cancel':
        final args = (call.arguments as Map).cast<String, Object?>();
        pending.remove(args['id']);
        log.add('cancel #${args['id']}');
        return null;
      case 'initialize':
      case 'requestNotificationsPermission':
      case 'canScheduleExactNotifications':
        return true;
      default:
        return null;
    }
  }

  /// What the OS would have shown by [now].
  List<({String title, DateTime at})> deliveredBy(DateTime now) =>
      pending.values.where((n) => !n.at.isAfter(now)).toList();
}

void main() {
  setUp(AndroidFlutterLocalNotificationsPlugin.registerWith);

  final android = TargetPlatformVariant.only(TargetPlatform.android);

  Future<(FixedClock, _FakeNotificationOs)> launch(WidgetTester tester) async {
    final os = _FakeNotificationOs();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      os.handle,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      ),
    );

    // Real "now", because the plugin rejects schedules in the past.
    final clock = FixedClock(DateTime.now().toUtc());
    await pumpApp(
      tester,
      clock: clock,
      settings: GardenSettings.defaults.withSessionLength(
        const Duration(minutes: 15),
      ),
      notifications: LocalSessionNotifications(
        plugin: FlutterLocalNotificationsPlugin(),
      ),
    );
    return (clock, os);
  }

  SessionPhase phase(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(PipGardenApp)),
  ).read(sessionControllerProvider).phase;

  /// A quick app switch where Dart gets no turn between leaving and coming
  /// back (the isolate is suspended in the background, or the switch is
  /// faster than the plugin's channel round trips).
  Future<void> quickSwitchAndBack(WidgetTester tester) async {
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await settle(tester);
  }

  /// The reported steps from minute 5 onwards. Returns what the OS delivered
  /// while the session sat paused.
  Future<List<({String title, DateTime at})>> pauseSwitchAndWait(
    WidgetTester tester,
    FixedClock clock,
    _FakeNotificationOs os,
    DateTime started,
  ) async {
    await advance(
      tester,
      clock,
      started.add(const Duration(minutes: 5)).difference(clock.now()),
    );
    await pauseSession(tester);
    await sendToBackground(tester);
    await advance(tester, clock, const Duration(minutes: 10));

    expect(phase(tester), SessionPhase.paused);
    return os.deliveredBy(clock.now());
  }

  testWidgets('the reported steps deliver nothing while paused', (
    tester,
  ) async {
    final (clock, os) = await launch(tester);
    final started = clock.now();
    await startSession(tester);

    expect(await pauseSwitchAndWait(tester, clock, os, started), isEmpty);
  }, variant: android);

  testWidgets('a normal away-and-back while running is cleaned up', (
    tester,
  ) async {
    final (clock, os) = await launch(tester);
    final started = clock.now();
    await startSession(tester);

    await advance(tester, clock, const Duration(minutes: 2));
    await sendToBackground(tester);
    await bringToForeground(tester);
    await settle(tester);

    expect(await pauseSwitchAndWait(tester, clock, os, started), isEmpty);
  }, variant: android);

  // The report: a stale "has bloomed" notice at start + 15 min, i.e. 10 min
  // after the pause, with the session still paused. Reproduced at each of
  // these switch times before the fix.
  for (final switchAt in const [
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 3, seconds: 30),
    Duration(minutes: 4, seconds: 50),
  ]) {
    testWidgets(
      'a quick switch at ${switchAt.inSeconds}s, then pausing, delivers '
      'nothing while paused',
      (tester) async {
        final (clock, os) = await launch(tester);
        final started = clock.now();
        await startSession(tester);

        await advance(tester, clock, switchAt);
        await quickSwitchAndBack(tester);
        expect(phase(tester), SessionPhase.running);

        expect(
          await pauseSwitchAndWait(tester, clock, os, started),
          isEmpty,
          reason: 'OS log: ${os.log}',
        );
      },
      variant: android,
    );
  }

  testWidgets('a cancel never overtakes an earlier schedule', (tester) async {
    // Without pausing, so only the ordering in LocalSessionNotifications is
    // tested: a stale notice here would fire while the app is open.
    final (clock, os) = await launch(tester);
    await startSession(tester);

    await advance(tester, clock, const Duration(minutes: 2));
    await quickSwitchAndBack(tester);

    expect(os.pending, isEmpty, reason: 'OS log: ${os.log}');
    expect(os.log.last, startsWith('cancel'));
  }, variant: android);

  testWidgets('pausing cancels a notice that is still pending', (tester) async {
    // Only the announcer: the fake applies calls instantly, so ordering can't
    // matter. Something left a notice pending; pausing must clear it.
    final clock = FixedClock(testInstant);
    final notifications = FakeSessionNotifications();
    await pumpApp(tester, clock: clock, notifications: notifications);

    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 5));
    notifications.pending = SessionCompletionNotice.forGrowth(
      null,
      at: testInstant.add(const Duration(minutes: 25)),
      sound: EndSound.windChime,
    );

    await pauseSession(tester);
    await settle(tester);

    expect(notifications.pending, isNull);
  });
}
