import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/app.dart';
import 'package:pip_garden/src/notifications/local_session_notifications.dart';
import 'package:pip_garden/src/notifications/session_notifications.dart';
import 'package:pip_garden/src/session/session_providers.dart';

import '../support/app_harness.dart';

// Two "Your break is over" notifications at once.
//
// With auto-start on, backgrounding during a session schedules the session end
// (#1) and the break end as a follow-up (#2). Backgrounding again during that
// break, with no resume in between, scheduled the break end a second time as
// #1 while #2 was still pending.
//
// Set up like paused_session_notification_test.dart: everything real except
// the OS side of the plugin's channel.

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

const _session = Duration(minutes: 5);
const _break = Duration(minutes: 5);

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
        log.add('schedule #${args['id']} "${args['title']}"');
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

  /// Titles of what the OS would have shown by [now].
  List<String> deliveredBy(DateTime now) => [
    for (final notice in pending.values)
      if (!notice.at.isAfter(now)) notice.title,
  ];
}

void main() {
  setUp(AndroidFlutterLocalNotificationsPlugin.registerWith);

  final android = TargetPlatformVariant.only(TargetPlatform.android);

  _FakeNotificationOs fakeOs(WidgetTester tester) {
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
    return os;
  }

  Future<(FixedClock, _FakeNotificationOs)> launch(WidgetTester tester) async {
    final os = fakeOs(tester);

    // Real "now", because the plugin rejects schedules in the past.
    final clock = FixedClock(DateTime.now().toUtc());
    await pumpApp(
      tester,
      clock: clock,
      settings: GardenSettings.defaults
          .withSessionLength(_session)
          .withBreakLength(_break)
          .withAutoStartBreak(enabled: true)
          .withAutoStartNextSession(enabled: true),
      notifications: LocalSessionNotifications(
        plugin: FlutterLocalNotificationsPlugin(),
      ),
    );
    return (clock, os);
  }

  SessionPhase phase(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(PipGardenApp)),
  ).read(sessionControllerProvider).phase;

  /// Paused a second time without a resume, e.g. the screen waking on the
  /// lock screen and going dark again.
  Future<void> lockAgain(WidgetTester tester) async {
    for (final state in const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await settle(tester);
  }

  /// Locks a minute into a session and stays locked until [intoBreak] of the
  /// auto-started break.
  Future<void> lockUntilBreak(
    WidgetTester tester,
    FixedClock clock,
    Duration intoBreak,
  ) async {
    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 1));
    await sendToBackground(tester);
    await settle(tester);

    await advance(
      tester,
      clock,
      _session - const Duration(minutes: 1) + intoBreak,
    );
    expect(phase(tester), SessionPhase.onBreak);
  }

  // Short or long; every fourth break is a long one.
  Iterable<String> breakEnds(Iterable<String> titles) =>
      titles.where((title) => title.endsWith('break is over'));

  Future<void> finishPhase(WidgetTester tester, FixedClock clock) {
    final due = ProviderScope.containerOf(
      tester.element(find.byType(PipGardenApp)),
    ).read(sessionControllerProvider).dueAt!;
    return advance(tester, clock, due.difference(clock.now()));
  }

  testWidgets('locking in a session schedules both ends', (tester) async {
    final (_, os) = await launch(tester);
    await startSession(tester);
    await sendToBackground(tester);
    await settle(tester);

    expect(os.pending.keys, unorderedEquals([1, 2]), reason: '${os.log}');
    expect(os.pending[2]!.title, 'Your break is over');
  }, variant: android);

  for (final intoBreak in const [
    Duration(seconds: 10),
    Duration(minutes: 1),
    Duration(minutes: 2, seconds: 30),
    Duration(minutes: 4),
    Duration(minutes: 4, seconds: 50),
  ]) {
    testWidgets(
      'locking again ${intoBreak.inSeconds}s into the break notifies once',
      (tester) async {
        final (clock, os) = await launch(tester);
        await lockUntilBreak(tester, clock, intoBreak);

        await lockAgain(tester);
        await advance(tester, clock, _break - intoBreak);

        expect(
          breakEnds(os.deliveredBy(clock.now())),
          hasLength(1),
          reason: 'OS log: ${os.log}',
        );
      },
      variant: android,
    );
  }

  testWidgets('five sessions back to back never double up', (tester) async {
    final (clock, os) = await launch(tester);
    await lockUntilBreak(tester, clock, const Duration(minutes: 1));

    for (var round = 0; round < 5; round++) {
      await lockAgain(tester);
      expect(
        breakEnds(os.pending.values.map((notice) => notice.title)),
        hasLength(1),
        reason: 'round $round, OS log: ${os.log}',
      );
      await finishPhase(tester, clock);
      expect(phase(tester), SessionPhase.running);

      await lockAgain(tester);
      expect(os.pending.keys, unorderedEquals([1, 2]));
      await finishPhase(tester, clock);
      expect(phase(tester), SessionPhase.onBreak);
    }
  }, variant: android);

  testWidgets('unlocking in between still leaves one', (tester) async {
    final (clock, os) = await launch(tester);
    await lockUntilBreak(tester, clock, const Duration(minutes: 1));

    await bringToForeground(tester);
    await settle(tester);
    await sendToBackground(tester);
    await settle(tester);
    await advance(tester, clock, _break);

    expect(breakEnds(os.deliveredBy(clock.now())), hasLength(1));
  }, variant: android);

  group('LocalSessionNotifications', () {
    SessionCompletionNotice notice(String title, Duration from) =>
        SessionCompletionNotice(
          at: DateTime.now().toUtc().add(from),
          title: title,
          body: 'body',
          sound: EndSound.none,
        );

    testWidgets('a new completion clears the old follow-up', (tester) async {
      final os = fakeOs(tester);
      final notifications = LocalSessionNotifications(
        plugin: FlutterLocalNotificationsPlugin(),
      );

      await notifications.scheduleCompletion(notice('session', _session));
      await notifications.scheduleFollowUp(notice('break', _session + _break));
      await notifications.scheduleCompletion(notice('break', _break));

      expect(os.pending.keys, [1], reason: '${os.log}');
      expect(os.pending[1]!.title, 'break');
    }, variant: android);

    testWidgets('a follow-up scheduled afterwards stays', (tester) async {
      final os = fakeOs(tester);
      final notifications = LocalSessionNotifications(
        plugin: FlutterLocalNotificationsPlugin(),
      );

      await notifications.scheduleCompletion(notice('session', _session));
      await notifications.scheduleFollowUp(notice('break', _session + _break));
      // Same again replaces both.
      await notifications.scheduleCompletion(notice('session', _session));
      await notifications.scheduleFollowUp(notice('break', _session + _break));

      expect(os.pending.keys, unorderedEquals([1, 2]), reason: '${os.log}');
    }, variant: android);

    testWidgets('cancelling clears both', (tester) async {
      final os = fakeOs(tester);
      final notifications = LocalSessionNotifications(
        plugin: FlutterLocalNotificationsPlugin(),
      );

      await notifications.scheduleCompletion(notice('session', _session));
      await notifications.scheduleFollowUp(notice('break', _session + _break));
      await notifications.cancelCompletion();

      expect(os.pending, isEmpty);
    }, variant: android);
  });
}
