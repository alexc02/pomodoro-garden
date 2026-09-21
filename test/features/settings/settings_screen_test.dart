import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_settings_repository.dart';
import 'package:pip_garden/src/design/palette.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/app_harness.dart';

void main() {
  /// Sets [key]'s slider to [value] via its callbacks. The pixel offset would
  /// depend on track width; the drag test below covers real gestures.
  Future<void> setSlider(WidgetTester tester, Key key, double value) async {
    final slider = tester.widget<Slider>(
      find.descendant(of: find.byKey(key), matching: find.byType(Slider)),
    );
    slider.onChanged!(value);
    await tester.pump();
    slider.onChangeEnd!(value);
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) =>
      tapTab(tester, AppTab.settings);

  group('initial state', () {
    testWidgets('first run shows defaults 25, 5, 4', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      expect(find.text('25 min'), findsOneWidget);
      expect(find.text('5 min'), findsOneWidget);
      expect(find.text('4 sessions'), findsOneWidget);
    });

    testWidgets('shows stored settings', (tester) async {
      await pumpApp(
        tester,
        settings: GardenSettings.defaults
            .withSessionLength(const Duration(minutes: 50))
            .withBreakLength(const Duration(minutes: 12))
            .withLongBreakAfter(6),
      );
      await openSettings(tester);

      expect(find.text('50 min'), findsOneWidget);
      expect(find.text('12 min'), findsOneWidget);
      expect(find.text('6 sessions'), findsOneWidget);
    });
  });

  group('the presets', () {
    testWidgets('short, classic and deep', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      expect(find.text('Short · 15'), findsOneWidget);
      expect(find.text('Classic · 25'), findsOneWidget);
      expect(find.text('Deep · 50'), findsOneWidget);
    });

    testWidgets('tapping one sets the session length', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.text('Deep · 50'));
      await tester.pumpAndSettle();

      expect(find.text('50 min'), findsOneWidget);
    });

    testWidgets("current length's preset is selected", (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      ChoiceChip chipFor(String label) =>
          tester.widget<ChoiceChip>(find.ancestor(
            of: find.text(label),
            matching: find.byType(ChoiceChip),
          ));

      // The default length is Classic.
      expect(chipFor('Classic · 25').selected, isTrue);
      expect(chipFor('Deep · 50').selected, isFalse);

      await tester.tap(find.text('Deep · 50'));
      await tester.pumpAndSettle();

      expect(chipFor('Deep · 50').selected, isTrue);
      expect(chipFor('Classic · 25').selected, isFalse);
    });

    testWidgets('custom length selects no preset', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await setSlider(tester, SettingsKeys.sessionLength, 37);

      expect(find.text('37 min'), findsOneWidget);
      for (final preset in SessionPreset.values) {
        expect(
          tester
              .widget<ChoiceChip>(
                  find.byKey(SettingsKeys.sessionPreset(preset)))
              .selected,
          isFalse,
        );
      }
    });

    testWidgets('re-tapping keeps it selected', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.text('Classic · 25'));
      await tester.pumpAndSettle();

      expect(find.text('25 min'), findsOneWidget);
    });
  });

  group('the break presets', () {
    ChoiceChip chip(WidgetTester tester, BreakPreset preset) =>
        tester.widget<ChoiceChip>(find.byKey(SettingsKeys.breakPreset(preset)));

    testWidgets('short, standard and long', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      await scrollToSetting(tester, SettingsKeys.breakPreset(BreakPreset.long));

      expect(find.text('Short · 5'), findsOneWidget);
      expect(find.text('Standard · 10'), findsOneWidget);
      expect(find.text('Long · 15'), findsOneWidget);
    });

    testWidgets('default break is Short', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      await scrollToSetting(tester, SettingsKeys.breakPreset(BreakPreset.short));

      expect(chip(tester, BreakPreset.short).selected, isTrue);
      expect(chip(tester, BreakPreset.long).selected, isFalse);
    });

    testWidgets('tapping one sets the break and slider', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await tester.tap(
        await scrollToSetting(tester, SettingsKeys.breakPreset(BreakPreset.long)),
      );
      await tester.pumpAndSettle();

      expect(find.text('15 min'), findsOneWidget);
      expect(chip(tester, BreakPreset.long).selected, isTrue);
      expect(chip(tester, BreakPreset.short).selected, isFalse);
    });

    testWidgets('custom break selects no preset', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await setSlider(tester, SettingsKeys.breakLength, 7);

      for (final preset in BreakPreset.values) {
        expect(chip(tester, preset).selected, isFalse);
      }
    });

    testWidgets('session and break presets are independent', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await tester.tap(
        await scrollToSetting(
          tester,
          SettingsKeys.breakPreset(BreakPreset.standard),
        ),
      );
      await tester.pumpAndSettle();

      final classic = await scrollToSetting(
        tester,
        SettingsKeys.sessionPreset(SessionPreset.classic),
      );
      expect(tester.widget<ChoiceChip>(classic).selected, isTrue);
    });
  });

  group('the custom controls', () {
    testWidgets('have the right ranges', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      Slider sliderAt(Key key) => tester.widget<Slider>(
            find.descendant(of: find.byKey(key), matching: find.byType(Slider)),
          );

      (double, double) boundsOf(Key key) =>
          (sliderAt(key).min, sliderAt(key).max);

      expect(boundsOf(SettingsKeys.sessionLength), (5.0, 120.0));
      expect(boundsOf(SettingsKeys.breakLength), (1.0, 30.0));
      expect(boundsOf(SettingsKeys.longBreakAfter), (2.0, 6.0));
    });

    testWidgets('snap to whole units', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      // One division per minute.
      expect(
        tester
            .widget<Slider>(find.descendant(
              of: find.byKey(SettingsKeys.sessionLength),
              matching: find.byType(Slider),
            ))
            .divisions,
        115,
      );
    });

    testWidgets('set all three settings', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await setSlider(tester, SettingsKeys.sessionLength, 90);
      await setSlider(tester, SettingsKeys.breakLength, 20);
      await setSlider(tester, SettingsKeys.longBreakAfter, 3);

      expect(find.text('90 min'), findsOneWidget);
      expect(find.text('20 min'), findsOneWidget);
      expect(find.text('3 sessions'), findsOneWidget);
    });

    testWidgets('dragging stops at the bound', (tester) async {
      // The only test using a real drag gesture.
      await pumpApp(tester, surface: const Size(400, 900));
      await openSettings(tester);

      final slider = find.descendant(
        of: find.byKey(SettingsKeys.breakLength),
        matching: find.byType(Slider),
      );
      // Starts low on screen under the chips, so scroll to it first.
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();

      await tester.drag(slider, const Offset(-1000, 0));
      await tester.pumpAndSettle();

      expect(find.text('1 min'), findsOneWidget);
    });
  });

  group('applying changes', () {
    testWidgets('next session uses the new length', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      await tester.tap(find.text('Deep · 50'));
      await tester.pumpAndSettle();

      await tapTab(tester, AppTab.timer);

      // The idle ring shows the next session's length.
      expect(find.text('50:00'), findsOneWidget);

      await tester.tap(find.text('Plant it'));
      await tester.pump();

      expect(find.text('50:00'), findsOneWidget);
      expect(find.text('Focusing'), findsOneWidget);
    });

    testWidgets('running session keeps its length', (tester) async {
      final clock = FixedClock(testInstant);
      await pumpApp(tester, clock: clock);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 1));
      expect(find.text('24:00'), findsOneWidget);

      await openSettings(tester);
      await tester.tap(find.text('Deep · 50'));
      await tester.pumpAndSettle();
      await tapTab(tester, AppTab.timer);

      // The running session got 25 minutes at start and keeps them.
      expect(find.text('24:00'), findsOneWidget);

      await advance(tester, clock, const Duration(minutes: 24));
      await settle(tester);
      expect(find.text('Session complete'), findsOneWidget);

      // New length applies from here.
      await tester.tap(find.text('Plant another'));
      await tester.pump();
      expect(find.text('50:00'), findsOneWidget);
    });
  });

  group('the haptics switch', () {
    /// Scrolls the haptics switch into view; it starts below the fold.
    Future<Finder> haptics(WidgetTester tester) =>
        scrollToSetting(tester, SettingsKeys.haptics);

    testWidgets('on by default', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      expect(tester.widget<SwitchListTile>(await haptics(tester)).value, isTrue,
          reason: 'on by default');
    });

    testWidgets('turns off and saves', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await pumpApp(tester, database: database);
      await openSettings(tester);

      await tester.tap(await haptics(tester));
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(await haptics(tester)).value,
          isFalse);
      expect(
        (await DriftSettingsRepository(database).load()).hapticsEnabled,
        isFalse,
      );
    });

    testWidgets('shows stored off state', (tester) async {
      await pumpApp(
        tester,
        settings: GardenSettings.defaults.withHaptics(enabled: false),
      );
      await openSettings(tester);

      expect(tester.widget<SwitchListTile>(await haptics(tester)).value,
          isFalse);
    });
  });

  group('the auto-start switches', () {
    Future<SwitchListTile> tile(WidgetTester tester, Key key) async =>
        tester.widget<SwitchListTile>(await scrollToSetting(tester, key));

    testWidgets('both off by default', (tester) async {
      // Off by default: don't start timers nobody asked for.
      await pumpApp(tester);
      await openSettings(tester);

      expect((await tile(tester, SettingsKeys.autoStartBreak)).value, isFalse);
      expect(
        (await tile(tester, SettingsKeys.autoStartNextSession)).value,
        isFalse,
      );
    });

    testWidgets('toggle independently and save', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await pumpApp(tester, database: database);
      await openSettings(tester);

      await tester.tap(
        await scrollToSetting(tester, SettingsKeys.autoStartBreak),
      );
      await tester.pumpAndSettle();

      expect((await tile(tester, SettingsKeys.autoStartBreak)).value, isTrue);
      expect(
        (await tile(tester, SettingsKeys.autoStartNextSession)).value,
        isFalse,
        reason: 'switches are independent',
      );

      final stored = await DriftSettingsRepository(database).load();
      expect(stored.autoStartBreak, isTrue);
      expect(stored.autoStartNextSession, isFalse);
    });

    testWidgets('show stored on state', (tester) async {
      await pumpApp(
        tester,
        settings: GardenSettings.defaults
            .withAutoStartBreak(enabled: true)
            .withAutoStartNextSession(enabled: true),
      );
      await openSettings(tester);

      expect((await tile(tester, SettingsKeys.autoStartBreak)).value, isTrue);
      expect(
        (await tile(tester, SettingsKeys.autoStartNextSession)).value,
        isTrue,
      );
    });
  });

  group('persistence', () {
    late Directory directory;
    late File file;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('pip_garden_test');
      file = File('${directory.path}/pip_garden.sqlite');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    testWidgets('every setting survives a relaunch', (tester) async {
      // Real file, closed between launches.
      final firstLaunch = AppDatabase.inFile(file);
      await pumpApp(tester, database: firstLaunch);
      await openSettings(tester);

      await setSlider(tester, SettingsKeys.sessionLength, 50);
      await setSlider(tester, SettingsKeys.breakLength, 12);
      await setSlider(tester, SettingsKeys.longBreakAfter, 6);
      await tester.tap(await scrollToSetting(tester, SettingsKeys.haptics));
      await tester.pumpAndSettle();
      await tester.tap(
        await scrollToSetting(tester, SettingsKeys.autoStartBreak),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        await scrollToSetting(tester, SettingsKeys.autoStartNextSession),
      );
      await tester.pumpAndSettle();

      await killApp(tester);
      await firstLaunch.close();

      final secondLaunch = AppDatabase.inFile(file);
      addTearDown(secondLaunch.close);
      await pumpApp(tester, database: secondLaunch);
      await openSettings(tester);

      expect(find.text('50 min'), findsOneWidget);
      expect(find.text('12 min'), findsOneWidget);
      expect(find.text('6 sessions'), findsOneWidget);

      expect(
        await DriftSettingsRepository(secondLaunch).load(),
        GardenSettings.defaults
            .withSessionLength(const Duration(minutes: 50))
            .withBreakLength(const Duration(minutes: 12))
            .withLongBreakAfter(6)
            .withHaptics(enabled: false)
            .withAutoStartBreak(enabled: true)
            .withAutoStartNextSession(enabled: true)
            // pumpApp launches past onboarding.
            .withOnboardingCompleted(),
      );
    });

    testWidgets('timer opens on the stored length after relaunch',
        (tester) async {
      final firstLaunch = AppDatabase.inFile(file);
      await pumpApp(tester, database: firstLaunch);
      await openSettings(tester);
      await tester.tap(find.text('Short · 15'));
      await tester.pumpAndSettle();

      await killApp(tester);
      await firstLaunch.close();

      final secondLaunch = AppDatabase.inFile(file);
      addTearDown(secondLaunch.close);
      await pumpApp(tester, database: secondLaunch);
      await tapTab(tester, AppTab.timer);

      expect(find.text('15:00'), findsOneWidget);
    });
  });

  testWidgets('fits a small phone at large text size', (tester) async {
    // An overflow throws and fails the test, so rendering at all is the check.
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester, surface: const Size(320, 568));
    await tapTab(tester, AppTab.settings);

    expect(find.text('Focus session'), findsOneWidget);

    // Scroll until visible: the test font is much wider than Inter, so fixed
    // distances aren't meaningful.
    await tester.scrollUntilVisible(
      find.text('Breaks'),
      300,
      scrollable: find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Breaks'), findsOneWidget);
  });

  group('light and dark', () {
    /// Scaffold colour comes from the theme, enough to tell light from dark.
    Color scaffoldColour(WidgetTester tester) {
      return tester
          .widget<Material>(find
              .descendant(
                of: find.byType(Scaffold).last,
                matching: find.byType(Material),
              )
              .first)
          .color!;
    }

    testWidgets('renders in light mode from the light tokens', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      expect(find.text('Focus session'), findsOneWidget);
      expect(scaffoldColour(tester), Palette.backgroundLight);
    });

    testWidgets('renders in dark mode from the dark tokens', (tester) async {
      useDarkMode(tester);
      await pumpApp(tester);
      await openSettings(tester);

      expect(find.text('Focus session'), findsOneWidget);
      expect(scaffoldColour(tester), Palette.backgroundDark);
    });
  });
}
