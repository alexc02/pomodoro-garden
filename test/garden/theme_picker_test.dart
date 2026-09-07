import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_settings_repository.dart';
import 'package:pip_garden/src/features/garden/theme_picker.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';

// The theme picker: what it shows and what tapping does. All three themes
// are free; the last group makes sure nothing locked comes back. See
// ADR 0005
void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  /// Tall enough for ListView to build all three cards and the note.
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

  /// The stored theme, read from disk.
  Future<GardenTheme> stored() async =>
      (await DriftSettingsRepository(database).load()).gardenTheme;

  group('contents', () {
    testWidgets('every theme is previewed', (tester) async {
      await launch(tester);
      await openPicker(tester);

      // All three cards with their real palettes, nothing blurred or locked.
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

    testWidgets('only the current theme has the tick', (tester) async {
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

    testWidgets('semantics include the selection', (tester) async {
      await launch(tester);
      await openPicker(tester);

      // The tick has no text, so state goes in the semantics label.
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

  group('applying', () {
    for (final theme in GardenTheme.values) {
      testWidgets('${theme.name} applies and saves', (tester) async {
        // One test per theme since each needs its own launch.
        await launch(tester);
        await openPicker(tester);
        await tapCard(tester, theme);

        expect(await stored(), theme);
      });
    }

    testWidgets('tick updates immediately', (tester) async {
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

    testWidgets('can change mid-session', (tester) async {
      // It's a setting, not something to block during a countdown.
      await launch(tester);
      await startSession(tester);
      await openPicker(tester);
      await tapCard(tester, GardenTheme.tropical);

      expect(await stored(), GardenTheme.tropical);
    });
  });

  group('no paywall', () {
    testWidgets('no card is locked', (tester) async {
      await launch(tester);
      await openPicker(tester);

      // What this screen used to have.
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
      expect(find.textContaining('premium', findRichText: true), findsNothing);
      expect(find.textContaining('Premium', findRichText: true), findsNothing);
    });

    testWidgets('mid-session tap opens nothing over the picker',
        (tester) async {
      await launch(tester);
      await startSession(tester);
      await openPicker(tester);
      await tapCard(tester, GardenTheme.tropical);

      expect(find.byType(ThemePickerScreen), findsOne);
    });
  });
}
