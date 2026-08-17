import 'package:flutter/material.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'garden_colors.dart';

/// How one [Season] looks in one theme. [applyTo] swaps in sky, soil,
/// foliage and bloom; text and decor colours are left alone.
///
/// There's no `SeasonPalette.of(season)`: each theme has its own spring etc.,
/// so get these from [ThemePalette].
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

  final Season season;
  final Color sky;
  final Color soil;
  final Color foliage;
  final Color bloom;

  /// What falls through the air, or null (summer has none).
  final Weather? weather;

  /// Colour for evergreens. Same as [foliage] except in winter, but set
  /// explicitly for every season anyway.
  final Color evergreen;

  GardenColors applyTo(GardenColors base) => base.copyWith(
        skyDay: sky,
        soil: soil,
        foliage: foliage,
        evergreenFoliage: evergreen,
        bloom: bloom,
      );
}

/// Falling particles for a season. [density] and `SeasonParticles.maximum`
/// are also a perf budget for big gardens.
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

  final WeatherShape shape;
  final Color colour;

  /// Peak opacity. Kept low so plants stay visible behind particles.
  final double opacity;

  /// Per 100,000 square logical pixels, so tablets get more. Capped by
  /// `SeasonParticles.maximum`.
  final double density;

  /// Time for the slowest particle to fall one screen height. Slow on
  /// purpose so it doesn't pull focus.
  final Duration crossing;

  /// Logical pixels.
  final double size;

  /// Side-to-side drift, in logical pixels.
  final double sway;
}

/// The three things this app knows how to drop out of the sky.
enum WeatherShape { petal, leaf, flake }
