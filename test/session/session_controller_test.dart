import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/garden/garden_reset_providers.dart';
import 'package:pip_garden/src/session/session_providers.dart';

import '../support/app_harness.dart';

/// Regressions for the QA pass in `docs/qa/bugs.md`, driven at the controller
/// rather than through the screen.
void main() {
  late FixedClock clock;
  late AppDatabase database;

  setUp(() {
    clock = FixedClock(testInstant);
    database = AppDatabase.forTesting();
  });
  tearDown(() => database.close());

  SessionController controller(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
          .read(sessionControllerProvider.notifier);

  Future<int> sessionRows() async => (await database
          .customSelect('SELECT COUNT(*) AS n FROM sessions')
          .getSingle())
      .read<int>('n');

  group('BUG-03: start asked for twice before either lands', () {
    testWidgets('starts one session and throws nothing', (tester) async {
      await pumpApp(tester, clock: clock, database: database);
      final session = controller(tester);

      await Future.wait([session.start(), session.start()]);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(await sessionRows(), 1);
    });

    testWidgets('a start over a held session leaves it held', (tester) async {
      await pumpApp(tester, clock: clock, database: database);
      final session = controller(tester);
      await session.start();
      await session.pause();

      await session.start();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
            .read(sessionControllerProvider)
            .phase,
        SessionPhase.paused,
      );
      expect(await sessionRows(), 1);
    });
  });

  group('BUG-01: the cycle across a relaunch', () {
    ProviderContainer container(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

    Future<void> completeOne(WidgetTester tester) async {
      await controller(tester).start();
      await advance(tester, clock, const Duration(minutes: 25));
      await controller(tester).catchUp();
    }

    testWidgets('three sessions, a relaunch, and the fourth earns the long '
        'break', (tester) async {
      await pumpApp(tester, clock: clock, database: database);
      for (var i = 0; i < 3; i++) {
        await completeOne(tester);
      }
      expect(container(tester).read(sessionControllerProvider).cyclePosition,
          3);

      await killApp(tester);
      await pumpApp(tester, clock: clock, database: database);
      expect(container(tester).read(sessionControllerProvider).cyclePosition,
          3, reason: 'the position is read back, not started over');

      await completeOne(tester);
      expect(container(tester).read(breakOnOfferProvider).kind,
          BreakKind.long);
    });

    testWidgets('a long break taken before the relaunch stays taken',
        (tester) async {
      await pumpApp(
        tester,
        clock: clock,
        database: database,
        settings: GardenSettings.defaults.withLongBreakAfter(2),
      );
      await completeOne(tester);
      await completeOne(tester);
      await controller(tester).startBreak();
      expect(container(tester).read(sessionControllerProvider).cyclePosition,
          0);

      await killApp(tester);
      await pumpApp(tester, clock: clock, database: database);
      await completeOne(tester);
      expect(container(tester).read(breakOnOfferProvider).kind,
          BreakKind.short);
    });
  });

  group('BUG-02: a garden reset and the cycle', () {
    ProviderContainer container(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

    testWidgets('starts the cycle over, and it stays over after a relaunch',
        (tester) async {
      await pumpApp(tester, clock: clock, database: database);
      for (var i = 0; i < 3; i++) {
        await controller(tester).start();
        await advance(tester, clock, const Duration(minutes: 25));
        await controller(tester).catchUp();
      }
      // Reset is only offered at rest: take the break and walk out of it.
      await controller(tester).startBreak();
      await controller(tester).skipBreak();

      expect(
        await container(tester).read(gardenResetControllerProvider.notifier)
            .clear(),
        ResetOutcome.cleared,
      );
      expect(container(tester).read(sessionControllerProvider).cyclePosition,
          0);

      await killApp(tester);
      await pumpApp(tester, clock: clock, database: database);
      expect(container(tester).read(sessionControllerProvider).cyclePosition,
          0);

      await controller(tester).start();
      await advance(tester, clock, const Duration(minutes: 25));
      await controller(tester).catchUp();
      expect(container(tester).read(breakOnOfferProvider).kind,
          BreakKind.short);
    });
  });
}
