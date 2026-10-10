import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/drift_session_repository.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';
import 'package:pomodoro_garden/src/time/clock_provider.dart';

import '../support/app_harness.dart';

/// The clock the app runs on is replaceable, at the container level and end to
/// end through the timer screen. A session's anchor is the value that proves
/// it: whatever clock the app was given is the one the session was started
/// against.
void main() {
  test('resolves to the system clock by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(clockProvider), isA<SystemClock>());
  });

  test('an override replaces the clock the container hands out', () {
    final fixed = FixedClock(testInstant);
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(fixed)],
    );
    addTearDown(container.dispose);

    expect(container.read(clockProvider), same(fixed));
    expect(container.read(clockProvider).now(), testInstant);
  });

  testWidgets('a session started on screen is anchored to the overridden clock',
      (tester) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final clock = FixedClock(testInstant);

    await pumpApp(tester, clock: clock, database: database);
    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);

    final session =
        (await DriftSessionRepository(database).completedSessions()).single;
    expect(session.startedAt, testInstant);
    expect(session.endedAt, testInstant.add(const Duration(minutes: 25)));
  });

  testWidgets('without an override the app runs on the system clock',
      (tester) async {
    await pumpApp(tester, useSystemClock: true);
    await tapTab(tester, AppTab.timer);

    // Read the clock out of the running app's own scope, rather than a
    // container built alongside it: what matters is what the widgets got.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    expect(container.read(clockProvider), isA<SystemClock>());
    expect(find.text('Ready to focus'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
  });
}
