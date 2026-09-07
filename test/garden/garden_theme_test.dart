import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/design/garden_colors.dart';
import 'package:pip_garden/src/design/garden_skin.dart';
import 'package:pip_garden/src/design/theme_palette.dart';

// The twelve theme/season palettes. We can't check how they look, so check
// that each is distinct and that no theme is less legible than the default.
void main() {
  group('combinations', () {
    test('every theme has a palette for every season', () {
      for (final theme in GardenTheme.values) {
        for (final season in Season.values) {
          final palette = ThemePalette.of(theme).inSeason(season);

          // Twelve near-identical entries is easy to copy-paste wrong.
          expect(
            palette.season,
            season,
            reason: '${theme.name} has the wrong palette under ${season.name}',
          );
        }
      }
    });

    test('all twelve are distinct', () {
      // Two identical combinations means one was never designed.
      final seen = <GardenColors, GardenSkin>{};

      for (final theme in GardenTheme.values) {
        for (final season in Season.values) {
          final skin = GardenSkin(theme: theme, season: season);
          final colours = skin.applyTo(GardenColors.light);

          expect(
            seen[colours],
            isNull,
            reason: '$skin is the same picture as ${seen[colours]}',
          );
          seen[colours] = skin;
        }
      }

      expect(seen, hasLength(GardenTheme.values.length * Season.values.length));
    });

    test('material is fixed per theme', () {
      // Material doesn't change with the season, which keeps a winter meadow
      // recognisable once the other colours go grey.
      for (final theme in GardenTheme.values) {
        final decors = {
          for (final season in Season.values)
            GardenSkin(theme: theme, season: season)
                .applyTo(GardenColors.light)
                .decor,
        };

        expect(
          decors,
          hasLength(1),
          reason: "${theme.name}'s material changes with the season",
        );
      }

      // No two themes share a material.
      final materials = {
        for (final theme in GardenTheme.values) ThemePalette.of(theme).decor,
      };
      expect(materials, hasLength(GardenTheme.values.length));
    });

    test('seasons change every theme', () {
      // And each theme still changes with the seasons (the greenhouse least).
      for (final theme in GardenTheme.values) {
        final skies = {
          for (final season in Season.values)
            ThemePalette.of(theme).inSeason(season).sky,
        };

        expect(
          skies,
          hasLength(Season.values.length),
          reason: '${theme.name} has the same sky in two seasons',
        );
      }
    });
  });

  group('dark mode', () {
    test('skin sets every garden colour', () {
      // Garden colours are illustration, not UI, so they don't follow
      // brightness. A skin overwrites all of them, so dark mode can't make
      // anything less legible than light mode.
      for (final theme in GardenTheme.values) {
        for (final season in Season.values) {
          final skin = GardenSkin(theme: theme, season: season);

          final light = skin.applyTo(GardenColors.light);
          final dark = skin.applyTo(GardenColors.dark);

          expect(dark.skyDay, light.skyDay, reason: '$skin sky');
          expect(dark.soil, light.soil, reason: '$skin soil');
          expect(dark.foliage, light.foliage, reason: '$skin foliage');
          expect(dark.bloom, light.bloom, reason: '$skin bloom');
          expect(dark.decor, light.decor, reason: '$skin decor');
          expect(
            dark.evergreenFoliage,
            light.evergreenFoliage,
            reason: '$skin evergreen',
          );
        }
      }
    });

    test('caption follows brightness', () {
      // But the caption under the garden is UI and must follow brightness.
      const skin = GardenSkin(theme: GardenTheme.zen, season: Season.summer);

      expect(
        skin.applyTo(GardenColors.dark).textPrimary,
        isNot(skin.applyTo(GardenColors.light).textPrimary),
      );
    });
  });

  group('legibility', () {
    test('no theme is less legible than the default', () {
      // The bar is Zen, not a WCAG ratio: the garden is low-contrast
      // watercolour where plants read by hue and shape. A WCAG check would fail
      // the default theme. This catches flowers disappearing into the soil.
      final floor = _legibilityFloor(GardenTheme.fallback);

      for (final theme in GardenTheme.values) {
        expect(
          _legibilityFloor(theme),
          greaterThanOrEqualTo(floor),
          reason: '${theme.name} is less legible than the default theme',
        );
      }
    });

    test('every combination meets the floor', () {
      // Absolute floor too, so repainting Zen can't lower the bar for all.
      for (final theme in GardenTheme.values) {
        expect(
          _legibilityFloor(theme),
          greaterThan(5),
          reason: '${theme.name} has a plant too close to its background',
        );
      }
    });
  });
}

/// Lowest plant-vs-background separation in [theme] across all seasons.
///
/// CIELAB, since a gold flower on a blue sky has similar luminance but
/// looks very different.
double _legibilityFloor(GardenTheme theme) {
  var worst = double.infinity;

  for (final season in Season.values) {
    final palette = ThemePalette.of(theme).inSeason(season);
    // What a plant is drawn over: the sky, and the plot tile as GardenAtlas
    // composites it (42% soil over sky).
    final sky = palette.sky;
    final plot = Color.lerp(sky, palette.soil, 0.42)!;

    for (final plant in [palette.foliage, palette.bloom, palette.evergreen]) {
      for (final ground in [sky, plot]) {
        worst = math.min(worst, _difference(plant, ground));
      }
    }
  }

  return worst;
}

/// CIE76 colour distance.
double _difference(Color a, Color b) {
  final first = _lab(a);
  final second = _lab(b);

  return math.sqrt(
    math.pow(first.l - second.l, 2) +
        math.pow(first.a - second.a, 2) +
        math.pow(first.b - second.b, 2),
  );
}

({double l, double a, double b}) _lab(Color colour) {
  double linear(double channel) => channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

  final r = linear(colour.r);
  final g = linear(colour.g);
  final b = linear(colour.b);

  // sRGB to XYZ, normalised to D65 white.
  final x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
  final y = r * 0.2126 + g * 0.7152 + b * 0.0722;
  final z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;

  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;

  final fx = f(x);
  final fy = f(y);
  final fz = f(z);

  return (l: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz));
}
