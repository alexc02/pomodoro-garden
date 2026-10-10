import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/design/garden_colors.dart';
import 'package:pomodoro_garden/src/features/timer/session_ring.dart';
import 'package:pomodoro_garden/src/features/timer/timer_screen.dart';
import 'package:pomodoro_garden/src/garden/growing_plant.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../../support/app_harness.dart';

/// The ring currently on screen.
SessionRing _ring(WidgetTester tester) =>
    tester.widget<SessionRing>(find.byType(SessionRing));

/// What the timer screen says is growing.
PlantGrowth? _growing(WidgetTester tester) =>
    tester.widget<GrowingPlant>(find.byType(GrowingPlant)).growth;

Future<void> _openTimer(WidgetTester tester, FixedClock clock) async {
  await pumpApp(tester, clock: clock);
  await tapTab(tester, AppTab.timer);
}

void main() {
  late FixedClock clock;

  setUp(() => clock = FixedClock(testInstant));

  testWidgets('before starting, the ring is empty and shows the session '
      'length', (tester) async {
    await _openTimer(tester, clock);

    expect(find.text('25:00'), findsOneWidget);
    expect(_ring(tester).progress, 0);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('tapping START counts the session down once per second',
      (tester) async {
    await _openTimer(tester, clock);
    await startSession(tester);

    expect(find.text('25:00'), findsOneWidget,
        reason: 'the first second still reads 25:00');

    await advance(tester, clock, const Duration(seconds: 1));
    expect(find.text('24:59'), findsOneWidget);

    await advance(tester, clock, const Duration(seconds: 1));
    expect(find.text('24:58'), findsOneWidget);
  });

  testWidgets('the ring fills in proportion to the time elapsed',
      (tester) async {
    await _openTimer(tester, clock);
    await startSession(tester);

    await advance(tester, clock, const Duration(minutes: 5));
    expect(_ring(tester).progress, closeTo(0.2, 1e-9));

    await advance(tester, clock, const Duration(minutes: 15));
    expect(_ring(tester).progress, closeTo(0.8, 1e-9));
  });

  testWidgets('a stalled UI does not cost the session time', (tester) async {
    // No frames for ten minutes — a stalled thread, a suspended app. The
    // countdown picks up where the wall clock actually is, not where the last
    // frame left it.
    await _openTimer(tester, clock);
    await startSession(tester);

    await advance(tester, clock, const Duration(minutes: 10));

    expect(find.text('15:00'), findsOneWidget);
  });

  testWidgets('reaching zero completes the session', (tester) async {
    await _openTimer(tester, clock);
    await startSession(tester);

    await advance(tester, clock, const Duration(minutes: 25));

    expect(find.text('00:00'), findsOneWidget);
    expect(_ring(tester).progress, 1);
    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget,
        reason: 'the next session can be started');
  });

  testWidgets('a completed session is counted on the screen', (tester) async {
    await _openTimer(tester, clock);
    expect(find.text('No sessions grown yet'), findsOneWidget);

    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);

    expect(find.text('1 session grown'), findsOneWidget);
  });

  group('the plant', () {
    testWidgets('before starting, the soil is bare', (tester) async {
      await _openTimer(tester, clock);

      expect(find.byType(GrowingPlant), findsOneWidget);
      expect(_growing(tester), isNull);
    });

    testWidgets('starting a session drops a seed', (tester) async {
      await _openTimer(tester, clock);
      await startSession(tester);

      expect(_growing(tester)!.stage, GrowthStage.seed);
    });

    testWidgets('the plant advances through all five stages as the session '
        'runs', (tester) async {
      await _openTimer(tester, clock);
      await startSession(tester);

      final seen = <GrowthStage>[_growing(tester)!.stage];
      for (var minute = 0; minute < 25; minute++) {
        await advance(tester, clock, const Duration(minutes: 1));
        final stage = _growing(tester)!.stage;
        if (stage != seen.last) seen.add(stage);
      }

      expect(seen, GrowthStage.values);
    });

    // REQ-015, end to end: the length the user chose in settings decides what
    // appears in their garden.
    Future<PlantType> grownBy(WidgetTester tester, Duration length) async {
      await pumpApp(
        tester,
        clock: clock,
        settings: GardenSettings.defaults.withSessionLength(length),
      );
      await tapTab(tester, AppTab.timer);
      await startSession(tester);
      return _growing(tester)!.type;
    }

    testWidgets('a 15-minute session grows a herb', (tester) async {
      expect(
        await grownBy(tester, const Duration(minutes: 15)),
        PlantType.herb,
      );
    });

    testWidgets('a 90-minute session grows a large tree', (tester) async {
      expect(
        await grownBy(tester, const Duration(minutes: 90)),
        PlantType.largeTree,
      );
    });

    testWidgets('fits a small phone at a large text size', (tester) async {
      // The plant is a second thing competing with the ring for the height of
      // the screen, and on the smallest supported phone at a large text size
      // the two of them push START below the fold. That is what the screen's
      // scroll view is for: an overflow would paint a striped bar and report an
      // exception, which fails this test, and scrolling does not.
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpApp(tester, clock: clock, surface: const Size(320, 568));
      await tapTab(tester, AppTab.timer);

      expect(find.byType(GrowingPlant), findsOneWidget);
      expect(tester.takeException(), isNull);

      // And START is still reachable, which is the one thing on this screen
      // that has to be.
      await tester.scrollUntilVisible(
        find.text('Start'),
        200,
        scrollable: find.descendant(
          of: find.byType(TimerScreen),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pump();

      expect(_growing(tester)!.stage, GrowthStage.seed);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the plant keeps growing while the user is on another tab',
        (tester) async {
      await _openTimer(tester, clock);
      await startSession(tester);

      await tapTab(tester, AppTab.garden);
      await advance(tester, clock, const Duration(minutes: 13));
      await tapTab(tester, AppTab.timer);

      expect(_growing(tester)!.stage, GrowthStage.young);
    });
  });

  group('light and dark', () {
    /// The colour the countdown is actually painted in.
    Color countdownColour(WidgetTester tester) =>
        tester.widget<Text>(find.text('20:00')).style!.color!;

    Future<void> runFiveMinutes(WidgetTester tester) async {
      await _openTimer(tester, clock);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
    }

    testWidgets('renders in light mode from the light tokens', (tester) async {
      await runFiveMinutes(tester);

      final context = tester.element(find.byType(SessionRing));
      expect(Theme.of(context).colorScheme.brightness, Brightness.light);
      expect(countdownColour(tester), GardenColors.light.textPrimary);
      expect(_ring(tester).progress, closeTo(0.2, 1e-9));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark mode from the dark tokens', (tester) async {
      useDarkMode(tester);
      await runFiveMinutes(tester);

      final context = tester.element(find.byType(SessionRing));
      expect(Theme.of(context).colorScheme.brightness, Brightness.dark);
      expect(countdownColour(tester), GardenColors.dark.textPrimary);
      expect(
        countdownColour(tester),
        isNot(GardenColors.light.textPrimary),
        reason: 'dark mode is not the light screen with a dark background',
      );
      expect(_ring(tester).progress, closeTo(0.2, 1e-9));
      expect(tester.takeException(), isNull);
    });
  });
}
