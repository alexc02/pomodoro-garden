import 'package:flutter/foundation.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'garden_colors.dart';
import 'season_palette.dart';
import 'theme_palette.dart';

/// A theme (user's choice) plus a season (from the device date). Both touch
/// the same colours, so the garden looks up the pair instead of applying them
/// one after the other.
@immutable
final class GardenSkin {
  const GardenSkin({required this.theme, required this.season});

  final GardenTheme theme;
  final Season season;

  ThemePalette get biome => ThemePalette.of(theme);

  SeasonPalette get palette => biome.inSeason(season);

  GardenColors applyTo(GardenColors base) => biome.applyTo(base, season);

  GardenSkin inSeason(Season season) =>
      GardenSkin(theme: theme, season: season);

  @override
  bool operator ==(Object other) =>
      other is GardenSkin && other.theme == theme && other.season == season;

  @override
  int get hashCode => Object.hash(theme, season);

  @override
  String toString() => 'GardenSkin(${theme.name}, ${season.name})';
}
