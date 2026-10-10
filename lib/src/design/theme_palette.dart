import 'package:flutter/material.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'garden_colors.dart';
import 'palette.dart';
import 'season_palette.dart';

/// What one [GardenTheme] looks like, in each of the four seasons. REQ-034.
///
/// **This is the twelve combinations, written out.** Three biomes times four
/// seasons, and every one of them is a value in a table rather than a rule
/// applied to another value. That is the decision this file is, and the
/// alternative was tempting: a season could have been a *transform* — a hue
/// rotation, a saturation shift — laid over whatever colours the theme
/// supplied, which would have been twelve pictures out of seven numbers.
///
/// It would also have been twelve pictures nobody chose. A meadow in November
/// is straw and seed heads; a greenhouse in November is green, because the
/// glass is the thing the season cannot get through. Those are two different
/// answers to "what does autumn do to this garden", and no transform gives
/// both. The ticket asks that every theme render correctly in all four seasons
/// and that the two systems compose rather than fight — and a table is what
/// makes "correctly" a thing somebody decided rather than a thing that fell
/// out of arithmetic.
///
/// The cost is honest and bounded: adding a fourth theme means writing four
/// palettes, and `theme_palette_test.dart` fails until all four are there.
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

  /// The biome these twelve colours a season are for.
  final GardenTheme theme;

  /// The material this garden's furniture is cut from — Zen's stone, the
  /// greenhouse's teak, the meadow's silvered fence wood.
  ///
  /// **One colour for the whole year**, and it is the only garden colour a
  /// season leaves alone. Everything else here turns with the calendar; a
  /// lantern does not. That is what keeps the three themes telling themselves
  /// apart in January, when the seasons have pulled all four of their other
  /// colours towards the same cold grey — without it, a winter meadow and a
  /// winter Zen garden would be very nearly the same picture.
  ///
  /// Ticket 20's placeable decor reads this same token, so its lanterns arrive
  /// already knowing which garden they are standing in.
  final Color decor;

  /// This theme in April.
  final SeasonPalette spring;

  /// This theme in July.
  final SeasonPalette summer;

  /// This theme in November.
  final SeasonPalette autumn;

  /// This theme in January.
  final SeasonPalette winter;

  /// This theme's palette for [season].
  SeasonPalette inSeason(Season season) => switch (season) {
        Season.spring => spring,
        Season.summer => summer,
        Season.autumn => autumn,
        Season.winter => winter,
      };

  /// [base] dressed as this theme, in [season].
  ///
  /// The material goes on first and the season goes on over it, which is the
  /// order the two systems compose in: a season may move the sky, the soil, the
  /// leaves and the flowers, and it never reaches the stone.
  GardenColors applyTo(GardenColors base, Season season) =>
      inSeason(season).applyTo(base.copyWith(decor: decor));

  /// The palette for [theme].
  static ThemePalette of(GardenTheme theme) => switch (theme) {
        GardenTheme.zen => zen,
        GardenTheme.tropical => tropical,
        GardenTheme.wildflower => wildflower,
      };

  /// REQ-034's free default: raked sand, stone and moss.
  ///
  /// **§5.1's palette is this theme's summer**, which is not a coincidence and
  /// is worth knowing before changing either: the app's own colours were drawn
  /// as a Zen garden in July, so every screenshot, every plant sprite and every
  /// seasonal shift in this app was measured against these four values. The
  /// other two themes are measured against them in turn.
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
        // The lightest of the three, and the slowest: a petal has further to
        // travel sideways than down.
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
    // "Bare branches" is a *colour* here and not a shape, and that is worth
    // being plain about: a plant's silhouette comes from its sprite, and the
    // sprites belong to ticket 23. So a January maple is drawn in bare wood
    // rather than drawn bare.
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
        // The densest of the three — thirty-five flakes on a phone, against
        // nineteen petals in spring. Snow is the one that has to read as
        // *weather* rather than as something drifting past.
        density: 11,
        crossing: Duration(seconds: 16),
        size: 3,
        sway: 14,
      ),
    ),
  );

  /// REQ-034's second biome: warm glass and deep leaf.
  ///
  /// **The greenhouse keeps its leaves, and that is the whole idea of it.**
  /// Its foliage is green in November and green in January, where Zen's turns
  /// amber and then to bare wood — because the glass is the thing a season
  /// cannot get through. What the season still does is the *light*: amber on
  /// the outside of the glass in autumn, cold and flat in winter, and the
  /// weather still falls, because it falls on the roof.
  ///
  /// That is what makes this theme compose with REQ-019 rather than ignore it.
  /// A greenhouse whose colours never moved at all would be a theme that had
  /// opted out of the seasons; this one answers them differently.
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
        // Thinner than Zen's, and settling rather than falling through: this
        // snow is on the *outside* of the roof, and the garden is under it.
        opacity: 0.55,
        density: 9,
        crossing: Duration(seconds: 18),
        size: 3,
        sway: 12,
      ),
    ),
  );

  /// REQ-034's third biome: open grass gone to seed.
  ///
  /// The theme that answers the seasons most loudly — a meadow is the thing in
  /// this app that most obviously has a November — and the one whose colour is
  /// scattered rather than arranged. Paler underfoot than Zen in every month,
  /// because a meadow is dry ground rather than tilled earth.
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
