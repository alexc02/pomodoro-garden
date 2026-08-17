import 'package:flutter/material.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'garden_colors.dart';
import 'palette.dart';
import 'season_palette.dart';

/// What one [GardenTheme] looks like in each season.
///
/// Twelve hand-picked palettes rather than a hue/saturation transform per
/// season, because themes react to seasons differently (a greenhouse stays
/// green in autumn, a meadow goes to straw). A new theme needs four palettes;
/// `theme_palette_test.dart` checks they're all there.
@immutable
final class ThemePalette {
  const ThemePalette({
    required this.theme,
    required this.decor,
    required this.spring,
    required this.summer,
    required this.autumn,
    required this.winter,
  });

  final GardenTheme theme;

  /// Decor material (stone, teak, fence wood). The same all year, which keeps
  /// themes distinguishable in winter when everything else goes grey.
  final Color decor;

  final SeasonPalette spring;
  final SeasonPalette summer;
  final SeasonPalette autumn;
  final SeasonPalette winter;

  SeasonPalette inSeason(Season season) => switch (season) {
        Season.spring => spring,
        Season.summer => summer,
        Season.autumn => autumn,
        Season.winter => winter,
      };

  /// Decor first, then the season on top. Seasons never touch decor.
  GardenColors applyTo(GardenColors base, Season season) =>
      inSeason(season).applyTo(base.copyWith(decor: decor));

  static ThemePalette of(GardenTheme theme) => switch (theme) {
        GardenTheme.zen => zen,
        GardenTheme.tropical => tropical,
        GardenTheme.wildflower => wildflower,
      };

  /// The default theme. The base palette was designed as Zen in summer, so
  /// the other themes and seasons are tuned relative to it.
  static const ThemePalette zen = ThemePalette(
    theme: GardenTheme.zen,
    decor: Palette.zenStone,
    spring: SeasonPalette(
      season: Season.spring,
      sky: Palette.springSky,
      soil: Palette.springSoil,
      foliage: Palette.springFoliage,
      evergreen: Palette.springFoliage,
      bloom: Palette.springBloom,
      weather: Weather(
        shape: WeatherShape.petal,
        colour: Palette.springPetal,
        opacity: 0.55,
        // Lightest and slowest; petals drift sideways more than down.
        density: 6,
        crossing: Duration(seconds: 26),
        size: 5,
        sway: 26,
      ),
    ),
    summer: SeasonPalette(
      season: Season.summer,
      sky: Palette.summerSky,
      soil: Palette.summerSoil,
      foliage: Palette.summerFoliage,
      evergreen: Palette.summerFoliage,
      bloom: Palette.summerBloom,
    ),
    autumn: SeasonPalette(
      season: Season.autumn,
      sky: Palette.autumnSky,
      soil: Palette.autumnSoil,
      foliage: Palette.autumnFoliage,
      evergreen: Palette.autumnFoliage,
      bloom: Palette.autumnBloom,
      weather: Weather(
        shape: WeatherShape.leaf,
        colour: Palette.autumnLeaf,
        opacity: 0.6,
        density: 6.5,
        crossing: Duration(seconds: 20),
        size: 7,
        sway: 34,
      ),
    ),
    // Bare branches are just a colour here; the sprites don't change shape.
    winter: SeasonPalette(
      season: Season.winter,
      sky: Palette.winterSky,
      soil: Palette.winterSoil,
      foliage: Palette.winterFoliage,
      evergreen: Palette.winterEvergreen,
      bloom: Palette.winterBloom,
      weather: Weather(
        shape: WeatherShape.flake,
        colour: Palette.winterSnow,
        opacity: 0.75,
        // Densest (about 35 flakes on a phone) so snow reads as weather.
        density: 11,
        crossing: Duration(seconds: 16),
        size: 3,
        sway: 14,
      ),
    ),
  );

  /// Greenhouse: foliage stays green all year, but the sky still shifts with
  /// the season and weather still falls (on the roof).
  static const ThemePalette tropical = ThemePalette(
    theme: GardenTheme.tropical,
    decor: Palette.tropicalTeak,
    spring: SeasonPalette(
      season: Season.spring,
      sky: Palette.tropicalSpringSky,
      soil: Palette.tropicalSpringSoil,
      foliage: Palette.tropicalSpringFoliage,
      evergreen: Palette.tropicalSpringFoliage,
      bloom: Palette.tropicalSpringBloom,
      weather: Weather(
        shape: WeatherShape.petal,
        colour: Palette.tropicalPetal,
        opacity: 0.5,
        density: 6,
        crossing: Duration(seconds: 26),
        size: 5,
        sway: 26,
      ),
    ),
    summer: SeasonPalette(
      season: Season.summer,
      sky: Palette.tropicalSummerSky,
      soil: Palette.tropicalSummerSoil,
      foliage: Palette.tropicalSummerFoliage,
      evergreen: Palette.tropicalSummerFoliage,
      bloom: Palette.tropicalSummerBloom,
    ),
    autumn: SeasonPalette(
      season: Season.autumn,
      sky: Palette.tropicalAutumnSky,
      soil: Palette.tropicalAutumnSoil,
      foliage: Palette.tropicalAutumnFoliage,
      evergreen: Palette.tropicalAutumnFoliage,
      bloom: Palette.tropicalAutumnBloom,
      weather: Weather(
        shape: WeatherShape.leaf,
        colour: Palette.tropicalLeaf,
        opacity: 0.5,
        density: 6.5,
        crossing: Duration(seconds: 20),
        size: 7,
        sway: 34,
      ),
    ),
    winter: SeasonPalette(
      season: Season.winter,
      sky: Palette.tropicalWinterSky,
      soil: Palette.tropicalWinterSoil,
      foliage: Palette.tropicalWinterFoliage,
      evergreen: Palette.tropicalWinterEvergreen,
      bloom: Palette.tropicalWinterBloom,
      weather: Weather(
        shape: WeatherShape.flake,
        colour: Palette.winterSnow,
        // Thinner than Zen's: it's snow on the glass outside.
        opacity: 0.55,
        density: 9,
        crossing: Duration(seconds: 18),
        size: 3,
        sway: 12,
      ),
    ),
  );

  /// Meadow: the most seasonal theme. Soil is paler than Zen's year-round.
  static const ThemePalette wildflower = ThemePalette(
    theme: GardenTheme.wildflower,
    decor: Palette.meadowWood,
    spring: SeasonPalette(
      season: Season.spring,
      sky: Palette.meadowSpringSky,
      soil: Palette.meadowSpringSoil,
      foliage: Palette.meadowSpringFoliage,
      evergreen: Palette.meadowSpringFoliage,
      bloom: Palette.meadowSpringBloom,
      weather: Weather(
        shape: WeatherShape.petal,
        colour: Palette.meadowPetal,
        opacity: 0.55,
        density: 6,
        crossing: Duration(seconds: 26),
        size: 5,
        sway: 30,
      ),
    ),
    summer: SeasonPalette(
      season: Season.summer,
      sky: Palette.meadowSummerSky,
      soil: Palette.meadowSummerSoil,
      foliage: Palette.meadowSummerFoliage,
      evergreen: Palette.meadowSummerFoliage,
      bloom: Palette.meadowSummerBloom,
    ),
    autumn: SeasonPalette(
      season: Season.autumn,
      sky: Palette.meadowAutumnSky,
      soil: Palette.meadowAutumnSoil,
      foliage: Palette.meadowAutumnFoliage,
      evergreen: Palette.meadowAutumnFoliage,
      bloom: Palette.meadowAutumnBloom,
      weather: Weather(
        shape: WeatherShape.leaf,
        colour: Palette.meadowLeaf,
        opacity: 0.6,
        density: 6.5,
        crossing: Duration(seconds: 20),
        size: 7,
        sway: 38,
      ),
    ),
    winter: SeasonPalette(
      season: Season.winter,
      sky: Palette.meadowWinterSky,
      soil: Palette.meadowWinterSoil,
      foliage: Palette.meadowWinterFoliage,
      evergreen: Palette.meadowWinterEvergreen,
      bloom: Palette.meadowWinterBloom,
      weather: Weather(
        shape: WeatherShape.flake,
        colour: Palette.winterSnow,
        opacity: 0.75,
        density: 11,
        crossing: Duration(seconds: 16),
        size: 3,
        sway: 18,
      ),
    ),
  );
}
