import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/design/garden_colors.dart';
import 'package:pip_garden/src/features/timer/progress_strip.dart';
import 'package:pip_garden/src/features/timer/timer_screen.dart';
import 'package:pip_garden/src/garden/growing_plant.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/app_harness.dart';

ProgressStrip _strip(WidgetTester tester) =>
    tester.widget<ProgressStrip>(find.byType(ProgressStrip));

PlantGrowth? _growing(WidgetTester tester) =>
    tester.widget<GrowingPlant>(find.byType(GrowingPlant)).growth;

Future<void> _openTimer(WidgetTester tester, FixedClock clock) async {
  await pumpApp(tester, clock: clock);
  await tapTab(tester, AppTab.timer);
}

void main() {
  late FixedClock clock;

  setUp(() => clock = FixedClock(testInstant));

  testWidgets('idle shows empty strip and session length', (tester) async {
    await _openTimer(tester, clock);

    expect(find.text('25:00'), findsOneWidget);
    expect(_strip(tester).progress, 0);
    expect(find.text('Plant it'), findsOneWidget);
  });

  testWidgets('START counts down each second', (tester) async {
    await _openTimer(tester, clock);
    await startSession(tester);

    expect(find.text('25:00'), findsOneWidget,
        reason: 'the first second still reads 25:00');

    await advance(tester, clock, const Duration(seconds: 1));
    expect(find.text('24:59'), findsOneWidget);

    await advance(tester, clock, const Duration(seconds: 1));
    expect(find.text('24:58'), findsOneWidget);
  });

  testWidgets('strip fills with elapsed time', (tester) async {
    await _openTimer(tester, clock);
    await startSession(tester);

    await advance(tester, clock, const Duration(minutes: 5));
    expect(_strip(tester).progress, closeTo(0.2, 1e-9));

    await advance(tester, clock, const Duration(minutes: 15));
    expect(_strip(tester).progress, closeTo(0.8, 1e-9));
  });

  testWidgets('stalled UI loses no time', (tester) async {
    // No frames for ten minutes. The countdown uses the wall clock.
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
    expect(_strip(tester).progress, 1);
    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('Plant another'), findsOneWidget,
        reason: 'ready for the next session');
  });

  testWidgets('shows completed count', (tester) async {
    await _openTimer(tester, clock);
    expect(find.text('No sessions grown yet'), findsOneWidget);

    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);

    expect(find.text('1 session grown'), findsOneWidget);
  });

  group('the plant', () {
    testWidgets('bare soil before starting', (tester) async {
      await _openTimer(tester, clock);

      expect(find.byType(GrowingPlant), findsOneWidget);
      expect(_growing(tester), isNull);
    });

    testWidgets('starting a session drops a seed', (tester) async {
      await _openTimer(tester, clock);
      await startSession(tester);

      expect(_growing(tester)!.stage, GrowthStage.seed);
    });

    testWidgets('plant goes through all five stages', (tester) async {
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

    // The session length from settings decides the plant type.
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
      // On the smallest phone at large text, plant and countdown push START
      // below the fold. The scroll view handles it; an overflow would fail.
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpApp(tester, clock: clock, surface: const Size(320, 568));
      await tapTab(tester, AppTab.timer);

      expect(find.byType(GrowingPlant), findsOneWidget);
      expect(tester.takeException(), isNull);

      // START must still be reachable.
      await tester.scrollUntilVisible(
        find.text('Plant it'),
        200,
        scrollable: find.descendant(
          of: find.byType(TimerScreen),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Plant it'));
      await tester.pump();

      expect(_growing(tester)!.stage, GrowthStage.seed);
      expect(tester.takeException(), isNull);
    });

    testWidgets('plant grows while on another tab', (tester) async {
      await _openTimer(tester, clock);
      await startSession(tester);

      await tapTab(tester, AppTab.garden);
      await advance(tester, clock, const Duration(minutes: 13));
      await tapTab(tester, AppTab.timer);

      expect(_growing(tester)!.stage, GrowthStage.young);
    });
  });

  group('light and dark', () {
    Color countdownColour(WidgetTester tester) =>
        tester.widget<Text>(find.text('20:00')).style!.color!;

    Future<void> runFiveMinutes(WidgetTester tester) async {
      await _openTimer(tester, clock);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
    }

    testWidgets('renders in light mode from the light tokens', (tester) async {
      await runFiveMinutes(tester);

      final context = tester.element(find.byType(ProgressStrip));
      expect(Theme.of(context).colorScheme.brightness, Brightness.light);
      expect(countdownColour(tester), GardenColors.light.textPrimary);
      expect(_strip(tester).progress, closeTo(0.2, 1e-9));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark mode from the dark tokens', (tester) async {
      useDarkMode(tester);
      await runFiveMinutes(tester);

      final context = tester.element(find.byType(ProgressStrip));
      expect(Theme.of(context).colorScheme.brightness, Brightness.dark);
      expect(countdownColour(tester), GardenColors.dark.textPrimary);
      expect(
        countdownColour(tester),
        isNot(GardenColors.light.textPrimary),
        reason: 'countdown colour changes in dark mode',
      );
      expect(_strip(tester).progress, closeTo(0.2, 1e-9));
      expect(tester.takeException(), isNull);
    });
  });
}
