import 'package:flutter/foundation.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'garden_colors.dart';
import 'season_palette.dart';
import 'theme_palette.dart';

/// How the garden is dressed right now: one biome, in one season.
///
/// **The pair, because neither half means anything alone.** REQ-034's theme and
/// REQ-019's season both reach the same five colours, and the ticket asks that
/// they compose rather than fight — so the thing the garden is actually painted
/// from is not a theme and not a season but the combination, and there are
/// twelve of them. Making that a value is what stops the two systems being
/// applied in some order at some call site: there is no order, there is a
/// lookup.
///
/// A skin is where the user's *choice* and the device's *date* meet, and it is
/// worth being clear which is which. The season cannot be chosen and the theme
/// cannot be inferred; a skin is one of each.
@immutable
final class GardenSkin {
  const GardenSkin({required this.theme, required this.season});

  /// The biome the user picked, and is entitled to.
  final GardenTheme theme;

  /// The season the device's date puts the garden in.
  final Season season;

  /// The twelve-way lookup: what this garden's colours are.
  ThemePalette get biome => ThemePalette.of(theme);

  /// What this garden's sky, soil, leaves and flowers look like.
  SeasonPalette get palette => biome.inSeason(season);

  /// [base] dressed as this skin.
  GardenColors applyTo(GardenColors base) => biome.applyTo(base, season);

  /// This skin in a different season, keeping the biome.
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
