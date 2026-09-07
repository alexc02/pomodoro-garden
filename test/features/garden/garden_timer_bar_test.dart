import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/feedback/micro_sounds.dart';
import 'package:pip_garden/src/features/garden/decor_picker.dart';
import 'package:pip_garden/src/features/garden/garden_timer_bar.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/announcement_fakes.dart';
import '../../support/app_harness.dart';

// One-tap start from the garden.
void main() {
  AppTab showing(WidgetTester tester) => AppTab.values[
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex];

  Future<void> startFromTheGarden(WidgetTester tester) async {
    await tester.tap(find.byKey(GardenTimerBarKeys.start));
    await settle(tester);
  }

  group('with nothing counting', () {
    testWidgets('starts a session in one tap', (tester) async {
      await pumpApp(tester);

      expect(showing(tester), AppTab.garden);
      expect(find.text('25-minute session'), findsOneWidget);

      await startFromTheGarden(tester);

      // Switches to the timer with the session running.
      expect(showing(tester), AppTab.timer);
      expect(find.text('Focusing'), findsOneWidget);
    });

    testWidgets('offers the length chosen in settings', (tester) async {
      await pumpApp(
        tester,
        settings: GardenSettings.defaults
            .withSessionLength(const Duration(minutes: 50)),
      );

      expect(find.text('50-minute session'), findsOneWidget);
    });

    testWidgets('plays the START sound', (tester) async {
      final sounds = FakeMicroSounds();
      await pumpApp(tester, microSounds: sounds);

      await startFromTheGarden(tester);

      expect(sounds.countOf(MicroSound.buttonTap), 1);
    });

    testWidgets('has a semantics label', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester);

      expect(
        find.bySemanticsLabel('Start a 25-minute session'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  group('with something counting', () {
    testWidgets('running session shows time left and links back',
        (tester) async {
      final clock = FixedClock(testInstant);
      await pumpApp(tester, clock: clock);

      await startFromTheGarden(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await tapTab(tester, AppTab.garden);

      expect(find.text('Focusing · 20:00 left'), findsOneWidget);
      expect(find.byKey(GardenTimerBarKeys.start), findsNothing);

      await tester.tap(find.byKey(GardenTimerBarKeys.bar));
      await settle(tester);

      expect(showing(tester), AppTab.timer);
    });

    testWidgets('a held session says so', (tester) async {
      final clock = FixedClock(testInstant);
      await pumpApp(tester, clock: clock);

      await startFromTheGarden(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await tester.tap(find.text('Pause'));
      await settle(tester);
      await tapTab(tester, AppTab.garden);

      expect(find.text('Paused · 20:00 left'), findsOneWidget);
    });

    testWidgets('a break shows the break', (tester) async {
      final clock = FixedClock(testInstant);
      await pumpApp(
        tester,
        clock: clock,
        settings: GardenSettings.defaults.withAutoStartBreak(enabled: true),
      );

      await startFromTheGarden(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);
      await tapTab(tester, AppTab.garden);

      expect(find.text('On a break · 05:00 left'), findsOneWidget);
    });
  });

  testWidgets('is gone while decor is being arranged', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(DecorKeys.arrange));
    await settle(tester);

    expect(find.byKey(GardenTimerBarKeys.bar), findsNothing);

    await tester.tap(find.byKey(DecorKeys.arrange));
    await settle(tester);

    expect(find.byKey(GardenTimerBarKeys.bar), findsOneWidget);
  });
}
