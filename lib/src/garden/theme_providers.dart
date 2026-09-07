import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../design/garden_skin.dart';
import '../settings/settings_providers.dart';
import 'season_providers.dart';

/// The garden theme (biome) the user picked. Settings load before the app
/// opens, so this is synchronous and never paints a theme nobody chose.
final gardenThemeProvider = Provider<GardenTheme>(
  (ref) => ref.watch(settingsProvider).gardenTheme,
);

/// The chosen theme in today's season. `SeasonalGarden` watches this and
/// cross-fades over three seconds when it changes.
final gardenSkinProvider = Provider<GardenSkin>((ref) {
  return GardenSkin(
    theme: ref.watch(gardenThemeProvider),
    season: ref.watch(seasonProvider),
  );
});
