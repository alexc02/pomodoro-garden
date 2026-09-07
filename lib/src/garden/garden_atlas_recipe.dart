import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../design/garden_colors.dart';
import 'decor_sprite.dart';
import 'garden_atlas.dart';
import 'plant_palettes.dart';
import 'plant_sprite.dart';

/// Turns a set of garden colours into an atlas recipe.
///
/// Shared by the garden screen and the export so the exported image always
/// matches what's on screen. `test/features/garden/export_flow_test.dart`
/// checks the two agree.
GardenAtlasRecipe gardenAtlasRecipe({
  required GardenColors colours,
  required PlantSpriteRegistry registry,
  required DecorSpriteRegistry decorRegistry,
}) =>
    GardenAtlasRecipe(
      registry: registry,
      palettes: {
        for (final species in PlantSpecies.values)
          species: plantPaletteIn(colours, species),
      },
      decorRegistry: decorRegistry,
      // Material follows the theme; water, shadow and lantern glow follow the
      // season. A season or theme change means a new recipe and a rebake.
      decorPalette: DecorPalette(
        material: colours.decor,
        water: colours.skyDay,
        shade: colours.soil,
        glow: colours.bloom,
      ),
      soil: colours.soil,
      decor: colours.decor,
    );
