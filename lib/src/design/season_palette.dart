import 'package:flutter/material.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'garden_colors.dart';

/// What one [Season] looks like *in one theme*: REQ-019 and REQ-034, as four
/// colours and whatever is falling through the air.
///
/// A season is a *skin over the garden's own tokens* rather than a second
/// palette beside them. It is applied by [applyTo], which hands back a
/// [GardenColors] with the season's sky, soil, foliage and bloom in place of
/// the theme's and everything else — the text colours, which follow the phone's
/// brightness and not the calendar, and the decor material, which follows the
/// biome and not the calendar — left exactly as it found it. That is the whole
/// mechanism, and it is why a season cannot reach anything but the garden:
/// nothing outside the garden's subtree is ever handed one.
///
/// **There is no `SeasonPalette.of(season)`, and that is REQ-034's doing.**
/// There is no such thing as "spring" on its own any more — there is Zen's
/// spring, the greenhouse's spring and the meadow's spring, and they are three
/// different pictures. The twelve of them are [ThemePalette]'s table, which is
/// the only thing that hands one of these out.
@immutable
final class SeasonPalette {
  const SeasonPalette({
    required this.season,
    required this.sky,
    required this.soil,
    required this.foliage,
    required this.bloom,
    required this.evergreen,
    this.weather,
  });

  /// The season these colours are for.
  final Season season;

  /// The backdrop the garden is drawn on.
  final Color sky;

  /// The ground, and the plot tiles cut out of it.
  final Color soil;

  /// Leaves and stems, for everything that has any this month.
  final Color foliage;

  /// Flowers and fruit.
  final Color bloom;

  /// What drifts down through this season's air, or null where nothing does.
  ///
  /// Null in summer, and that is REQ-019 read literally: it gives summer
  /// "vibrant flowers, bright sky" and names falling things only for the other
  /// three. A fourth particle would be an invention, and an empty summer sky is
  /// also what makes the two seasons either side of it feel like weather.
  final Weather? weather;

  /// The green kept by a plant that does not drop its leaves.
  ///
  /// Equal to [foliage] for three seasons of the year — spring, summer and
  /// autumn do not sort plants into evergreen and not — and written out at each
  /// of them rather than defaulted, so that the one season where the two differ
  /// is a value in a table beside three others rather than an exception to a
  /// rule.
  final Color evergreen;

  /// [base] with this season's colours in it.
  GardenColors applyTo(GardenColors base) => base.copyWith(
        skyDay: sky,
        soil: soil,
        foliage: foliage,
        evergreenFoliage: evergreen,
        bloom: bloom,
      );
}

/// What falls through a season's air, and how.
///
/// Everything here is a *budget* as much as a look. [density] and
/// `SeasonParticles.maximum` together are what keep REQ-019's ambience from
/// costing the two-hundred-plant garden its frame rate, and they are numbers
/// rather than an emergent count for exactly that reason.
@immutable
final class Weather {
  const Weather({
    required this.shape,
    required this.colour,
    required this.opacity,
    required this.density,
    required this.crossing,
    required this.size,
    required this.sway,
  });

  /// What one of them is drawn as.
  final WeatherShape shape;

  /// The colour it is drawn in.
  final Color colour;

  /// How solid one is at its most solid.
  ///
  /// Well under opaque, and that is the ticket's "does not obscure plants" as a
  /// number: what is behind a leaf on its way past is still visible through it,
  /// so nothing the user is looking at can be hidden by weather.
  final double opacity;

  /// How many are in the air, per hundred thousand square logical pixels.
  ///
  /// Per area rather than a flat count so that a tablet does not show the same
  /// dozen flakes spread across four times the sky — and capped absolutely by
  /// `SeasonParticles.maximum`, so that "per area" cannot become an unbounded
  /// number on a screen nobody tested on.
  final double density;

  /// How long the slowest of them takes to fall the height of the screen.
  ///
  /// Slow on purpose. §5.3 asks for calm, and the garden is a place to look at
  /// rather than a weather effect; anything quick enough to draw the eye is too
  /// quick.
  final Duration crossing;

  /// How big one is drawn, in logical pixels.
  final double size;

  /// How far one wanders from side to side on its way down, in logical pixels.
  final double sway;
}

/// The three things this app knows how to drop out of the sky.
enum WeatherShape { petal, leaf, flake }
