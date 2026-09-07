import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_decor_repository.dart';
import 'package:pip_garden/src/design/palette.dart';
import 'package:pip_garden/src/design/theme_palette.dart';
import 'package:pip_garden/src/features/garden/garden_view.dart';
import 'package:pip_garden/src/garden/decor_sprite.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/garden/season_providers.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/decor_fixtures.dart';
import '../support/garden_seed.dart';

// Decor follows the garden theme and season, checked against the recipe the
// atlas was baked from.
//
// Material stays fixed by theme; the season only changes what an
// object holds: pond water, ground shadow, lantern light.

/// Decor colours from the last bake.
DecorPalette _decorPalette(WidgetTester tester) {
  final view = tester.widget<CustomPaint>(find.descendant(
    of: find.byType(GardenView),
    matching: find.byType(CustomPaint),
  ).first);

  return (view.painter! as GardenPainter).atlas.signature.decorPalette;
}

void main() {
  /// Current database. Closed before the next opens since drift warns about
  /// a second connection.
  AppDatabase? database;

  Future<void> closeDatabase() async {
    await database?.close();
    database = null;
  }

  tearDown(closeDatabase);

  /// A garden with one decor item, in [theme], on [day].
  Future<void> open(
    WidgetTester tester, {
    required GardenTheme theme,
    required DateTime day,
  }) async {
    await closeDatabase();
    final opened = database = AppDatabase.forTesting();
    await seedGarden(opened, sessions: 2);
    await DriftDecorRepository(opened)
        .save(testDecor(DecorKind.pond, GardenPlots.inPlacementOrder[4]));
    await pumpApp(
      tester,
      database: opened,
      settings: GardenSettings.defaults.withGardenTheme(theme),
      clock: FixedClock(day),
      surface: const Size(500, 900),
      overrides: [hemisphereProvider.overrideWithValue(Hemisphere.northern)],
    );
    await tapTab(tester, AppTab.garden);
  }

  final summer = DateTime(2026, 7, 12, 10);
  final winter = DateTime(2026, 1, 12, 10);

  testWidgets('decor uses the theme material', (tester) async {
    await open(tester, theme: GardenTheme.tropical, day: summer);

    expect(_decorPalette(tester).material, Palette.tropicalTeak);
  });

  testWidgets('each theme has its own material', (tester) async {
    for (final theme in GardenTheme.values) {
      await open(tester, theme: theme, day: summer);
      expect(
        _decorPalette(tester).material,
        ThemePalette.of(theme).decor,
        reason: theme.name,
      );

      await killApp(tester);
    }
  });

  testWidgets('material is fixed across seasons', (tester) async {
    // Teak stays teak in winter, otherwise themes would look alike.
    await open(tester, theme: GardenTheme.wildflower, day: summer);
    final inSummer = _decorPalette(tester);

    await killApp(tester);
    await open(tester, theme: GardenTheme.wildflower, day: winter);
    final inWinter = _decorPalette(tester);

    expect(inWinter.material, inSummer.material);
  });

  testWidgets('contents change with the season', (tester) async {
    // Pond water reflects the seasonal sky.
    await open(tester, theme: GardenTheme.wildflower, day: summer);
    final inSummer = _decorPalette(tester);

    await killApp(tester);
    await open(tester, theme: GardenTheme.wildflower, day: winter);
    final inWinter = _decorPalette(tester);

    expect(inWinter.water, isNot(inSummer.water));
    expect(inWinter.shade, isNot(inSummer.shade));
    expect(inWinter, isNot(inSummer));
  });
}
