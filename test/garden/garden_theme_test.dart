import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/design/garden_colors.dart';
import 'package:pomodoro_garden/src/design/garden_skin.dart';
import 'package:pomodoro_garden/src/design/theme_palette.dart';

/// REQ-034's twelve combinations: three biomes, four seasons, and the two
/// criteria that are about what they look like rather than how they are picked.
///
/// The ticket asks that every theme render correctly in all four seasons — all
/// twelve reviewed — and that plant sprites stay legible against all three
/// backgrounds in both light and dark mode. Neither of those is a thing a test
/// can *see*, so what is asserted here is the two properties that would have to
/// hold for the eye to agree: every combination is a distinct, deliberate
/// palette, and nothing sold is harder to read than the thing given away.
void main() {
  group('the twelve combinations', () {
    test('every theme has a palette for every season', () {
      for (final theme in GardenTheme.values) {
        for (final season in Season.values) {
          final palette = ThemePalette.of(theme).inSeason(season);

          // Filed under the right season — [ThemePalette] is twelve
          // near-identical entries, which is exactly the shape a copy-paste
          // gets wrong silently.
          expect(
            palette.season,
            season,
            reason: '${theme.name} has the wrong palette under ${season.name}',
          );
        }
      }
    });

    test('all twelve are different pictures', () {
      // The whole point of the table. If two combinations resolved to the same
      // colours, one of the two was never designed — and the user who paid for
      // it would be looking at a garden they already had.
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

    test('a theme stays itself all year, because its material does', () {
      // The one colour a season does not move, and the reason a January meadow
      // still reads as a meadow: by winter the seasons have pulled all four of
      // the other colours towards the same cold grey.
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

      // And no two themes are cut from the same material.
      final materials = {
        for (final theme in GardenTheme.values) ThemePalette.of(theme).decor,
      };
      expect(materials, hasLength(GardenTheme.values.length));
    });

    test('a season still moves the garden, in every theme', () {
      // The other half of "the two systems compose rather than fight". A theme
      // that answered the calendar with the same four colours all year would
      // have opted out of REQ-019 — which is a thing the greenhouse comes
      // closest to doing, and does not do.
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

  group('the garden looks the same in dark mode', () {
    test('a skin decides every garden colour, whatever the base theme was', () {
      // **This is the whole of "in both light and dark mode".** The garden's
      // colours are the illustration rather than UI chrome, so they do not
      // follow the phone's brightness — and because a skin overwrites every one
      // of them, dark mode cannot introduce an illegibility that light mode
      // does not have. That is a property worth proving rather than eyeballing
      // twelve screenshots twice.
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

    test('and the text over it still follows the phone', () {
      // The other side of the same line: a skin reaches the illustration and
      // stops. The caption along the bottom of the garden has to stay readable
      // on a dark screen, so its colour is the one thing here brightness still
      // owns.
      const skin = GardenSkin(theme: GardenTheme.zen, season: Season.summer);

      expect(
        skin.applyTo(GardenColors.dark).textPrimary,
        isNot(skin.applyTo(GardenColors.light).textPrimary),
      );
    });
  });

  group('plants stay legible against every background', () {
    test('no theme is harder to read than the default', () {
      // **The bar is Zen, not a number out of a standard.** §5.1's garden is a
      // deliberately low-contrast watercolour — plants read by hue and by
      // shape, not by luminance — so a WCAG ratio would fail the free theme
      // that has shipped since ticket 07 and would be a bar this app's art
      // direction never agreed to.
      //
      // What can be asked honestly is that the other two are at least as
      // readable as the one every garden starts in. That is the regression this
      // catches: a garden whose flowers disappear into its own soil.
      final floor = _legibilityFloor(GardenTheme.fallback);

      for (final theme in GardenTheme.values) {
        expect(
          _legibilityFloor(theme),
          greaterThanOrEqualTo(floor),
          reason: '${theme.name} is less legible than the default theme',
        );
      }
    });

    test('every combination separates its plants from its ground', () {
      // A floor in absolute terms as well as a relative one, so that a future
      // repaint of Zen cannot quietly lower the bar for everything else by
      // lowering itself.
      for (final theme in GardenTheme.values) {
        expect(
          _legibilityFloor(theme),
          greaterThan(5),
          reason: '${theme.name} has a plant that vanishes into its garden',
        );
      }
    });
  });
}

/// The least separable a plant ever gets from what it is standing against, in
/// [theme], across all four seasons.
///
/// Measured in CIE L\*a\*b\*, which is the space that agrees with the eye about
/// a gold flower on a blue sky — those two are nearly identical in luminance
/// and about as different as two colours get. A luminance-only measure calls
/// that pair illegible and is wrong.
double _legibilityFloor(GardenTheme theme) {
  var worst = double.infinity;

  for (final season in Season.values) {
    final palette = ThemePalette.of(theme).inSeason(season);
    // What a plant is actually drawn over: the sky, and the plot tile as
    // `GardenAtlas` composites it — 42% soil over that sky, not raw soil.
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

/// How far apart two colours look, as a CIE76 distance.
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

  // sRGB to XYZ, then normalised against the D65 white point.
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
