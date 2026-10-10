import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/drift_settings_repository.dart';
import 'package:pomodoro_garden/src/design/palette.dart';
import 'package:pomodoro_garden/src/features/settings/settings_screen.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../../support/app_harness.dart';

void main() {
  /// Drags [key]'s slider to a whole-unit [value].
  ///
  /// The slider is driven through its own callbacks rather than by a gesture
  /// with a computed pixel offset: the offset that lands on 50 depends on the
  /// width the test surface happens to give the track, and a test that has to
  /// know that is testing arithmetic. `drags to the end of its range` below
  /// covers the gesture itself.
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

  group('what the screen opens on', () {
    testWidgets('a first run shows the defaults: 25, 5, and 4', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      expect(find.text('25 min'), findsOneWidget);
      expect(find.text('5 min'), findsOneWidget);
      expect(find.text('4 sessions'), findsOneWidget);
    });

    testWidgets('settings already stored are what it shows', (tester) async {
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
    testWidgets('are REQ-006 short, classic and deep, in one tap each',
        (tester) async {
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

    testWidgets('the one the current length is on shows as selected',
        (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      ChoiceChip chipFor(String label) =>
          tester.widget<ChoiceChip>(find.ancestor(
            of: find.text(label),
            matching: find.byType(ChoiceChip),
          ));

      // The default length *is* the Classic preset, so it reads as chosen
      // without the user having chosen it.
      expect(chipFor('Classic · 25').selected, isTrue);
      expect(chipFor('Deep · 50').selected, isFalse);

      await tester.tap(find.text('Deep · 50'));
      await tester.pumpAndSettle();

      expect(chipFor('Deep · 50').selected, isTrue);
      expect(chipFor('Classic · 25').selected, isFalse);
    });

    testWidgets('a custom length leaves every preset unselected',
        (tester) async {
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

    testWidgets('tapping the selected preset again leaves it selected',
        (tester) async {
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

    testWidgets('are REQ-007 short, standard and long, in one tap each',
        (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      await scrollToSetting(tester, SettingsKeys.breakPreset(BreakPreset.long));

      expect(find.text('Short · 5'), findsOneWidget);
      expect(find.text('Standard · 10'), findsOneWidget);
      expect(find.text('Long · 15'), findsOneWidget);
    });

    testWidgets('the default break is the Short preset, and shows as chosen',
        (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      await scrollToSetting(tester, SettingsKeys.breakPreset(BreakPreset.short));

      expect(chip(tester, BreakPreset.short).selected, isTrue);
      expect(chip(tester, BreakPreset.long).selected, isFalse);
    });

    testWidgets('tapping one sets the break length, and the slider follows',
        (tester) async {
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

    testWidgets('a break length no preset names leaves them all unselected',
        (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await setSlider(tester, SettingsKeys.breakLength, 7);

      for (final preset in BreakPreset.values) {
        expect(chip(tester, preset).selected, isFalse);
      }
    });

    testWidgets('a session preset and a break preset do not touch each other',
        (tester) async {
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
    testWidgets('offer exactly REQ-030\'s ranges', (tester) async {
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

    testWidgets('land only on whole units', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      // One division per minute, per session: the readout can then show the
      // value exactly, and there is no length between two minutes to store.
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

    testWidgets('set each of the three settings', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await setSlider(tester, SettingsKeys.sessionLength, 90);
      await setSlider(tester, SettingsKeys.breakLength, 20);
      await setSlider(tester, SettingsKeys.longBreakAfter, 3);

      expect(find.text('90 min'), findsOneWidget);
      expect(find.text('20 min'), findsOneWidget);
      expect(find.text('3 sessions'), findsOneWidget);
    });

    testWidgets('drag to the end of a range and it stops at the bound',
        (tester) async {
      // The one test that uses a real gesture, so that "the slider is wired up"
      // is proven by a finger rather than by calling its callbacks.
      await pumpApp(tester, surface: const Size(400, 900));
      await openSettings(tester);

      final slider = find.descendant(
        of: find.byKey(SettingsKeys.breakLength),
        matching: find.byType(Slider),
      );
      // REQ-007's chips sit above it, so on this surface it starts low on the
      // screen; a finger scrolls to it before dragging it.
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();

      await tester.drag(slider, const Offset(-1000, 0));
      await tester.pumpAndSettle();

      expect(find.text('1 min'), findsOneWidget);
    });
  });

  group('what a change reaches', () {
    testWidgets('the next session started uses the new length', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      await tester.tap(find.text('Deep · 50'));
      await tester.pumpAndSettle();

      await tapTab(tester, AppTab.timer);

      // The idle ring shows the length of the session about to be started.
      expect(find.text('50:00'), findsOneWidget);

      await tester.tap(find.text('Start'));
      await tester.pump();

      expect(find.text('50:00'), findsOneWidget);
      expect(find.text('Focusing'), findsOneWidget);
    });

    testWidgets('a session already running keeps the length it began with',
        (tester) async {
      final clock = FixedClock(testInstant);
      await pumpApp(tester, clock: clock);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 1));
      expect(find.text('24:00'), findsOneWidget);

      await openSettings(tester);
      await tester.tap(find.text('Deep · 50'));
      await tester.pumpAndSettle();
      await tapTab(tester, AppTab.timer);

      // Not 49:00, and not 50:00. The running session was handed 25 minutes
      // when it started and has never asked again.
      expect(find.text('24:00'), findsOneWidget);

      // And it still ends when its own 25 minutes are up.
      await advance(tester, clock, const Duration(minutes: 24));
      await settle(tester);
      expect(find.text('Session complete'), findsOneWidget);

      // Only now does the new length take over.
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(find.text('50:00'), findsOneWidget);
    });
  });

  group('the haptics switch', () {
    /// Brings the switch on screen and returns it. It sits below the two length
    /// sections, so on the default test surface it starts below the fold.
    Future<Finder> haptics(WidgetTester tester) =>
        scrollToSetting(tester, SettingsKeys.haptics);

    testWidgets('is on for a user who has never touched it', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      expect(tester.widget<SwitchListTile>(await haptics(tester)).value, isTrue,
          reason: 'REQ-037 is on by default');
    });

    testWidgets('turns REQ-037 off, and stores it', (tester) async {
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

    testWidgets('shows off when that is what was stored', (tester) async {
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
    /// Both of REQ-032's switches, by the key each is built with.
    Future<SwitchListTile> tile(WidgetTester tester, Key key) async =>
        tester.widget<SwitchListTile>(await scrollToSetting(tester, key));

    testWidgets('are both off for a user who has never touched them',
        (tester) async {
      // The ticket's default, and not a preference: an app that starts counting
      // something nobody asked for has taken a decision away from the user.
      await pumpApp(tester);
      await openSettings(tester);

      expect((await tile(tester, SettingsKeys.autoStartBreak)).value, isFalse);
      expect(
        (await tile(tester, SettingsKeys.autoStartNextSession)).value,
        isFalse,
      );
    });

    testWidgets('turn on one at a time, and store what they are set to',
        (tester) async {
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
        reason: 'two switches, not one — plenty of people want only this half',
      );

      final stored = await DriftSettingsRepository(database).load();
      expect(stored.autoStartBreak, isTrue);
      expect(stored.autoStartNextSession, isFalse);
    });

    testWidgets('show on when that is what was stored', (tester) async {
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
      directory = Directory.systemTemp.createTempSync('pomodoro_garden_test');
      file = File('${directory.path}/pomodoro_garden.sqlite');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    testWidgets('every setting survives a kill and a relaunch', (tester) async {
      // A real file, closed between the two launches, for the same reason the
      // session persistence test uses one: an in-memory database would prove
      // only that the app can re-read its own process.
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
            // Not something this test set: `pumpApp` launches past REQ-003's
            // onboarding, the way a user on their second day does.
            .withOnboardingCompleted(),
      );
    });

    testWidgets('a stored session length is what the timer opens on after a '
        'relaunch', (tester) async {
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

  testWidgets('fits a small phone at a large text size', (tester) async {
    // An overflow paints a striped bar and reports an exception, which fails
    // this test — so the assertion is that the screen renders at all. The
    // controls are stacked in a scrolling list precisely so that they can.
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester, surface: const Size(320, 568));
    await tapTab(tester, AppTab.settings);

    expect(find.text('Focus session'), findsOneWidget);

    // And everything below the fold is reachable rather than cut off. Scrolled
    // until it appears rather than by a fixed distance: widget tests measure
    // text in a stand-in font whose glyphs are far wider than Nunito's, so how
    // far down the second section sits here is not a real distance.
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
    /// The scaffold's colour is the theme's, so it tells the two apart without
    /// this test knowing anything about the settings screen's own paint.
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
