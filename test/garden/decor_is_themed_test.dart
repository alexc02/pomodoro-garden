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

/// REQ-040's fifth criterion: decor is themed consistently with the garden's
/// theme *and* its season.
///
/// Both halves are asserted against the recipe the atlas was actually baked
/// from, because that is what the pixels came out of — a test that read the
/// theme's colours back out of the theme would be asserting that a table
/// contains what it contains.
///
/// **Three of the four colours move and one does not**, which is not a
/// compromise but the design: ticket 19 kept the biome's material out of the
/// seasonal table (ADR 0016) so that the three gardens stay told apart in
/// January, and what a season reaches here is what an object *holds* — a pond's
/// water, the shadow on the ground, a lantern's light.

/// The colours the garden's decor was last baked in.
DecorPalette _decorPalette(WidgetTester tester) {
  final view = tester.widget<CustomPaint>(find.descendant(
    of: find.byType(GardenView),
    matching: find.byType(CustomPaint),
  ).first);

  return (view.painter! as GardenPainter).atlas.signature.decorPalette;
}

void main() {
  /// The database the app on screen is running on, closed as the next one
  /// opens.
  ///
  /// A fresh one per launch because every test here compares two gardens, and
  /// closed rather than left to a teardown so that only one is ever open —
  /// drift warns about a second connection, and a warning nobody can act on is
  /// noise across the whole suite.
  AppDatabase? database;

  Future<void> closeDatabase() async {
    await database?.close();
    database = null;
  }

  tearDown(closeDatabase);

  /// A garden with one object standing in it, in [theme], on [day].
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

  testWidgets('an object is cut from the biome it is standing in',
      (tester) async {
    await open(tester, theme: GardenTheme.tropical, day: summer);

    expect(_decorPalette(tester).material, Palette.tropicalTeak);
  });

  testWidgets('and every biome cuts it from something different',
      (tester) async {
    // The three materials, each reached through the garden the user is actually
    // in. `ThemePalette` is where they are written down; this is that they
    // arrive.
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

  testWidgets('the material holds still through the year', (tester) async {
    // ADR 0016's decision, at the scale this ticket adds: a teak bench is teak
    // in January. Without this the winter meadow and the winter Zen garden
    // would be nearly the same picture, and the user would have paid for
    // something that vanishes for three months a year.
    await open(tester, theme: GardenTheme.wildflower, day: summer);
    final inSummer = _decorPalette(tester);

    await killApp(tester);
    await open(tester, theme: GardenTheme.wildflower, day: winter);
    final inWinter = _decorPalette(tester);

    expect(inWinter.material, inSummer.material);
  });

  testWidgets('and what it holds turns with the season', (tester) async {
    // The other half, and the reason the criterion says "and season": a pond in
    // January is not a pond in July, because the sky it is reflecting is not.
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
