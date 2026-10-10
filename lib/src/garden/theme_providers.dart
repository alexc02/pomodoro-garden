import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../design/garden_skin.dart';
import '../settings/settings_providers.dart';
import 'season_providers.dart';

/// REQ-034's biome: which garden the user's plants are standing in.

/// What the garden is dressed in. REQ-034.
///
/// The stored choice, and nothing between it and the paint. An earlier draft
/// filtered this through a purchase and fell back to Zen for a device that had
/// not made one; the app is free, so what the user picked is what the garden is
/// — see `docs/adr/0021-…`.
///
/// Synchronous, because the settings are: they are read before the app opens,
/// so there is no frame in which the garden is drawn in a theme the user did
/// not choose.
final gardenThemeProvider = Provider<GardenTheme>(
  (ref) => ref.watch(settingsProvider).gardenTheme,
);

/// How the garden is dressed right now: the chosen theme, in today's season.
///
/// The one thing the garden is painted from, and the pair REQ-034 and REQ-019
/// meet in. Watched by `SeasonalGarden`, which turns it over three seconds
/// rather than in a frame.
final gardenSkinProvider = Provider<GardenSkin>((ref) {
  return GardenSkin(
    theme: ref.watch(gardenThemeProvider),
    season: ref.watch(seasonProvider),
  );
});
