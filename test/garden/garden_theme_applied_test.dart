import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_settings_repository.dart';
import 'package:pip_garden/src/design/garden_colors.dart';
import 'package:pip_garden/src/design/palette.dart';
import 'package:pip_garden/src/design/theme_palette.dart';
import 'package:pip_garden/src/features/garden/garden_view.dart';
import 'package:pip_garden/src/features/garden/seasonal_garden.dart';
import 'package:pip_garden/src/features/garden/theme_picker.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/garden/growing_plant.dart';
import 'package:pip_garden/src/garden/season_providers.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/garden_seed.dart';

// Themes on the garden itself: the choice persists across relaunch, and a
// switch crossfades without moving plants. See ADR 0005 for why there
// is no entitlement fallback any more.

GardenColors _garden(WidgetTester tester) => GardenColors.of(
      tester.element(find.byType(GardenView)),
    );

/// A quad's anchor point and draw scale.
typedef _Placement = ({Offset at, double scale});

/// Anchor of every plot and plant as the painter draws them.
///
/// Anchors, not raw transforms: sway changes all of RSTransform's numbers, but
/// the point a quad hangs from (tile middle, plant bottom middle) doesn't
/// change under rotation. Same maths as [RSTransform.fromComponents], reversed.
List<_Placement> _positions(WidgetTester tester) {
  final view = tester.widget<CustomPaint>(find.descendant(
    of: find.byType(GardenView),
    matching: find.byType(CustomPaint),
  ).first);

  final painter = view.painter! as GardenPainter;
  final atlas = painter.atlas;
  final batch = painter.batchFor(tester.getSize(find.byType(GardenView)));

  return [
    for (var index = 0; index < batch.rects.length; index++)
      () {
        final rect = batch.rects[index];
        final transform = batch.transforms[index];
        final ground = rect == atlas.emptySoil || rect == atlas.plantedSoil;

        // Tiles hang from their middle; occupants from the bottom middle.
        final anchorX = rect.width / 2;
        final anchorY = ground ? rect.height / 2 : rect.height;

        return (
          at: Offset(
            transform.tx + transform.scos * anchorX - transform.ssin * anchorY,
            transform.ty + transform.ssin * anchorX + transform.scos * anchorY,
          ),
          scale: math.sqrt(
            transform.scos * transform.scos + transform.ssin * transform.ssin,
          ),
        );
      }(),
  ];
}

/// Tall enough to build and tap all three preview cards without scrolling.
const _tall = Size(600, 2400);

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  /// A garden with something in it, in [theme].
  Future<void> open(
    WidgetTester tester, {
    required GardenTheme theme,
    DateTime? local,
  }) async {
    await seedGarden(database, sessions: 3);
    await pumpApp(
      tester,
      database: database,
      settings: GardenSettings.defaults.withGardenTheme(theme),
      clock: FixedClock(local ?? DateTime(2026, 7, 12, 10)),
      surface: _tall,
      overrides: [
        hemisphereProvider.overrideWithValue(Hemisphere.northern),
      ],
    );
    await tapTab(tester, AppTab.garden);
  }

  /// Picks [theme] in the picker and returns to the garden.
  Future<void> pick(WidgetTester tester, GardenTheme theme) async {
    await tapTab(tester, AppTab.settings);
    await tester.tap(await scrollToSetting(tester, SettingsKeys.gardenTheme));
    await settle(tester);
    await tester.tap(find.byKey(ThemePickerKeys.card(theme)));
    await settle(tester);
    await tester.tap(find.byType(BackButton).first);
    await settle(tester);
    await tapTab(tester, AppTab.garden);
  }

  group('applied theme', () {
    testWidgets('opens in the saved theme', (tester) async {
      await open(tester, theme: GardenTheme.tropical);

      expect(_garden(tester).skyDay, Palette.tropicalSummerSky);
      expect(_garden(tester).soil, Palette.tropicalSummerSoil);
      expect(_garden(tester).decor, Palette.tropicalTeak);
    });

    testWidgets('every theme reaches the garden', (tester) async {
      for (final theme in GardenTheme.values) {
        expect(
          ThemePalette.of(theme).summer.sky,
          isNotNull,
          reason: '${theme.name} has no summer',
        );
      }
    });

    testWidgets('theme only affects the garden', (tester) async {
      await open(tester, theme: GardenTheme.wildflower);

      // Only the garden subtree is themed, not the rest of the app.
      final outside = GardenColors.of(
        tester.element(find.byType(NavigationBar)),
      );

      expect(_garden(tester).skyDay, Palette.meadowSummerSky);
      expect(outside.skyDay, Palette.skyDay);
      expect(outside.decor, Palette.zenStone);
    });
  });

  group('persistence', () {
    testWidgets('survives relaunch', (tester) async {
      await seedGarden(database, sessions: 2);
      await pumpApp(tester, database: database, surface: _tall);

      await pick(tester, GardenTheme.tropical);

      await killApp(tester);
      await pumpApp(tester, database: database, surface: _tall);
      await tapTab(tester, AppTab.garden);

      expect(_garden(tester).decor, Palette.tropicalTeak);

      // Tear down here: the garden logs garden_viewed on dispose, and doing
      // that after the database closed would fail the next test.
      await killApp(tester);
    });

    testWidgets('opens without a crossfade', (tester) async {
      // The first frame is already the right theme; no crossfade from Zen.
      await open(tester, theme: GardenTheme.wildflower);

      expect(_garden(tester).skyDay, Palette.meadowSummerSky);
    });
  });

  group('switching', () {
    testWidgets('crossfades between themes', (tester) async {
      await open(tester, theme: GardenTheme.zen);
      expect(_garden(tester).skyDay, Palette.summerSky);

      await tapTab(tester, AppTab.settings);
      await tester.tap(await scrollToSetting(tester, SettingsKeys.gardenTheme));
      await settle(tester);

      // Count frames instead of settling: the crossfade is 3s and settle would
      // finish it. [settle] rather than one long pump, which only draws one
      // frame.
      Future<void> step() =>
          settle(tester, over: const Duration(milliseconds: 350));

      await tester.tap(find.byKey(ThemePickerKeys.card(GardenTheme.tropical)));
      await tester.pump();
      await tester.tap(find.byType(BackButton).first);
      await step();
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(AppTab.garden.label),
      ));
      await step();

      expect(
        find.byType(GardenView),
        findsOne,
        reason: 'did not get back to the garden',
      );

      final midway = _garden(tester).skyDay;
      expect(midway, isNot(Palette.summerSky));
      expect(midway, isNot(Palette.tropicalSummerSky));

      await settle(tester, over: SeasonalGarden.crossfade);
      expect(_garden(tester).skyDay, Palette.tropicalSummerSky);
    });

    testWidgets("plants don't move", (tester) async {
      await open(tester, theme: GardenTheme.zen);
      final before = _positions(tester);

      await pick(tester, GardenTheme.wildflower);
      await settle(tester, over: SeasonalGarden.crossfade);

      // A crossfade is colour only. Every plot and plant stays put.
      final after = _positions(tester);
      expect(after, hasLength(before.length));
      for (var i = 0; i < before.length; i++) {
        // Tolerance for float32 precision only.
        expect(after[i].at.dx, closeTo(before[i].at.dx, 1 / 16),
            reason: 'quad $i moved sideways');
        expect(after[i].at.dy, closeTo(before[i].at.dy, 1 / 16),
            reason: 'quad $i moved down');
        expect(after[i].scale, closeTo(before[i].scale, 1 / 16),
            reason: 'quad $i changed size');
      }
    });
  });

  group('running session', () {
    testWidgets('keeps growing across a theme change', (tester) async {
      // No code path from theme to session; the plant must not restart, skip a
      // stage or lose time.
      final clock = FixedClock(DateTime.utc(2026, 7, 12, 10));
      await seedGarden(database, sessions: 1);
      await pumpApp(
        tester,
        database: database,
        clock: clock,
        surface: _tall,
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 12));

      final growingBefore = tester.widget<GrowingPlant>(
        find.byType(GrowingPlant),
      ).growth;

      await tapTab(tester, AppTab.settings);
      await tester.tap(await scrollToSetting(tester, SettingsKeys.gardenTheme));
      await settle(tester);
      await tester.tap(find.byKey(ThemePickerKeys.card(GardenTheme.tropical)));
      await settle(tester);
      await tester.tap(find.byType(BackButton).first);
      await settle(tester);
      await tapTab(tester, AppTab.timer);

      final growingAfter = tester.widget<GrowingPlant>(
        find.byType(GrowingPlant),
      ).growth;

      // Same plant, same stage, same session.
      expect(growingBefore, isNotNull);
      expect(growingAfter, isNotNull);
      expect(growingAfter!.stage, growingBefore!.stage);
      expect(growingAfter.type, growingBefore.type);
      expect(growingAfter.species, growingBefore.species);
      expect(find.text('Pause'), findsOne);
    });
  });

  group('no filtering', () {
    testWidgets('stored theme is applied as is', (tester) async {
      // No entitlement in between any more; this would catch one coming back.
      await open(tester, theme: GardenTheme.wildflower);

      expect(_garden(tester).skyDay, Palette.meadowSummerSky);
      expect(
        (await DriftSettingsRepository(database).load()).gardenTheme,
        GardenTheme.wildflower,
      );
    });

    testWidgets('settings shows the same theme', (tester) async {
      // The settings row and the picker must agree.
      await open(tester, theme: GardenTheme.wildflower);
      await tapTab(tester, AppTab.settings);
      await scrollToSetting(tester, SettingsKeys.gardenTheme);

      expect(find.text('Theme: Wildflower Meadow'), findsOne);
    });
  });

  group('themes and seasons', () {
    testWidgets('greenhouse changes with the season', (tester) async {
      // Greenhouse in November: amber light on the glass, nothing inside
      // turning. The two most different combinations.
      await open(
        tester,
        theme: GardenTheme.tropical,
        local: DateTime(2026, 11, 12, 10),
      );

      expect(_garden(tester).skyDay, Palette.tropicalAutumnSky);
      expect(_garden(tester).foliage, Palette.tropicalAutumnFoliage);
      // Material doesn't change with the season.
      expect(_garden(tester).decor, Palette.tropicalTeak);
    });

    testWidgets('default theme changes with the season', (tester) async {
      await open(
        tester,
        theme: GardenTheme.zen,
        local: DateTime(2026, 11, 12, 10),
      );

      expect(_garden(tester).skyDay, Palette.autumnSky);
      expect(_garden(tester).decor, Palette.zenStone);
    });
  });
}
