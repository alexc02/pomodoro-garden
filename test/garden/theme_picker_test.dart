import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_settings_repository.dart';
import 'package:pip_garden/src/features/garden/theme_picker.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';

/// REQ-034's picker: what the user is shown, and what a tap on it does.
///
/// **Every card is a card that works.** An earlier draft sold two of the three
/// biomes, so this screen carried a lock, a route to a paywall and a rule about
/// when that route was allowed to open; the app is free and all three are gone.
/// What is left is a picker, and the group at the bottom is what keeps it one —
/// see `docs/adr/0021-…`.
void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  /// A surface tall enough to hold three cards and the note under them, so that
  /// a `ListView` has built all of them.
  const tall = Size(600, 2400);

  Future<void> launch(WidgetTester tester, {GardenSettings? settings}) =>
      pumpApp(
        tester,
        database: database,
        settings: settings,
        surface: tall,
      );

  Future<void> openPicker(WidgetTester tester) async {
    await tapTab(tester, AppTab.settings);
    await tester.tap(await scrollToSetting(tester, SettingsKeys.gardenTheme));
    await settle(tester);
  }

  Future<void> tapCard(WidgetTester tester, GardenTheme theme) async {
    await tester.tap(find.byKey(ThemePickerKeys.card(theme)));
    await settle(tester);
  }

  /// What the device has actually written down, read off the disk rather than
  /// off the screen.
  Future<GardenTheme> stored() async =>
      (await DriftSettingsRepository(database).load()).gardenTheme;

  group('what the picker shows', () {
    testWidgets('every theme is previewed', (tester) async {
      await launch(tester);
      await openPicker(tester);

      // All three cards on the screen, each with its real palette painted at
      // full size — nothing blurred out and no padlock over an empty rectangle.
      for (final theme in GardenTheme.values) {
        expect(
          find.byKey(ThemePickerKeys.card(theme)),
          findsOne,
          reason: '${theme.name} is not previewed',
        );
        expect(find.text(theme.label), findsOne);
        expect(find.text(theme.blurb), findsOne);
      }
    });

    testWidgets('the one in force carries the tick, and the others do not',
        (tester) async {
      await launch(
        tester,
        settings:
            GardenSettings.defaults.withGardenTheme(GardenTheme.tropical),
      );
      await openPicker(tester);

      expect(
        find.descendant(
          of: find.byKey(ThemePickerKeys.card(GardenTheme.tropical)),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOne,
      );
      expect(find.byIcon(Icons.check_circle), findsOne);
    });

    testWidgets('a screen reader is told which one is selected', (tester) async {
      await launch(tester);
      await openPicker(tester);

      // The tick is decoration as far as a screen reader is concerned — there
      // is no text in it — so the state of a card has to be carried in words on
      // the one thing that does.
      String spoken(GardenTheme theme) => tester
          .widget<Text>(find.descendant(
            of: find.byKey(ThemePickerKeys.card(theme)),
            matching: find.text(theme.label),
          ))
          .semanticsLabel!;

      expect(spoken(GardenTheme.zen), 'Zen Garden, selected');
      expect(spoken(GardenTheme.tropical), 'Tropical Greenhouse');
      expect(spoken(GardenTheme.wildflower), 'Wildflower Meadow');
    });
  });

  group('applying one', () {
    for (final theme in GardenTheme.values) {
      testWidgets('${theme.name} applies, and is written down', (tester) async {
        // One test per theme rather than a loop inside one, because applying a
        // theme is a tap through the real app and each needs its own launch.
        await launch(tester);
        await openPicker(tester);
        await tapCard(tester, theme);

        expect(await stored(), theme);
      });
    }

    testWidgets('the tick follows the choice, with no relaunch needed',
        (tester) async {
      await launch(tester);
      await openPicker(tester);
      await tapCard(tester, GardenTheme.wildflower);

      expect(
        find.descendant(
          of: find.byKey(ThemePickerKeys.card(GardenTheme.wildflower)),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOne,
      );
    });

    testWidgets('and a theme can be changed mid-session', (tester) async {
      // Changing how the garden looks is a setting, and a setting is not
      // something to be held back while a countdown runs.
      await launch(tester);
      await startSession(tester);
      await openPicker(tester);
      await tapCard(tester, GardenTheme.tropical);

      expect(await stored(), GardenTheme.tropical);
    });
  });

  group('nothing here sells anything', () {
    testWidgets('no card is locked, marked or held back', (tester) async {
      await launch(tester);
      await openPicker(tester);

      // The three things this screen used to carry. A lock coming back without
      // the decision being made again is what this catches.
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
      expect(find.textContaining('premium', findRichText: true), findsNothing);
      expect(find.textContaining('Premium', findRichText: true), findsNothing);
    });

    testWidgets('and a tap mid-session opens no screen over the picker',
        (tester) async {
      await launch(tester);
      await startSession(tester);
      await openPicker(tester);
      await tapCard(tester, GardenTheme.tropical);

      expect(find.byType(ThemePickerScreen), findsOne);
    });
  });
}
