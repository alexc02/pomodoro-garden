import 'package:flutter/painting.dart';

/// Raw colour literals. Widgets should read colours from the theme
/// (`colorScheme`, [GardenColors]) rather than from here.
abstract final class Palette {
  /// Foliage green.
  static const Color primary = Color(0xFF6B8E5A);

  static const Color soil = Color(0xFF8B6F47);
  static const Color skyDay = Color(0xFFB8D4E8);
  static const Color skyGoldenHour = Color(0xFFF5C99B);

  /// Only for reward moments (flowering plants, milestones).
  static const Color accentBloom = Color(0xFFE89B9B);

  static const Color backgroundDark = Color(0xFF1C2B1C);

  /// Same value as [moss].
  static const Color textPrimary = Color(0xFF22361F);

  /// Darker than the original `#6B7B6B`, which failed 4.5:1 contrast on
  /// [backgroundLight].
  static const Color textSecondary = Color(0xFF4D5E48);

  // --- Chrome ---------------------------------------------------------------
  //
  // UI controls. Separate from [primary], which is the leaf colour.

  /// Light theme primary: tab bar, filled buttons, sliders.
  static const Color moss = Color(0xFF22361F);

  /// Main-action accent, and the dark theme primary ([moss] is invisible on
  /// the dark canvas).
  static const Color marigold = Color(0xFFE8A33D);

  /// Unselected tab labels on [moss]; light primary container.
  static const Color mist = Color(0xFFCFE0DA);

  /// Timer pot: body, rim, and the shadow line under the rim.
  static const Color clay = Color(0xFFC2693E);
  static const Color clayRim = Color(0xFFD9824F);
  static const Color clayShade = Color(0xFF9A4E2A);

  // --- Surfaces and text -----------------------------------------------------

  /// Cream canvas. Also the text colour on filled [moss] controls.
  static const Color backgroundLight = Color(0xFFF3E9D2);

  /// Cards and sheets in light mode.
  static const Color surfaceLight = Color(0xFFFFF8EA);

  static const Color surfaceDark = Color(0xFF263826);
  static const Color textPrimaryDark = Color(0xFFE8EFE6);
  static const Color textSecondaryDark = Color(0xFFA3B3A0);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Material defaults; the palette has no error tone of its own.
  static const Color error = Color(0xFFB3261E);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorDark = Color(0xFFF2B8B5);
  static const Color onErrorDark = Color(0xFF601410);

  // --- Seasons (Zen) ---------------------------------------------------------
  //
  // Sky, soil, foliage, bloom, plus whatever falls through the air. Only
  // `season_palette.dart` reads these. The base tokens above are roughly
  // summer.

  static const Color springSky = Color(0xFFCBE3F2);
  static const Color springSoil = Color(0xFF7A6244);
  static const Color springFoliage = Color(0xFF8FB86A);
  static const Color springBloom = Color(0xFFF3C0CE);

  /// Falling blossom.
  static const Color springPetal = Color(0xFFF7D3DE);

  static const Color summerSky = Color(0xFF9CCBE8);
  static const Color summerSoil = Color(0xFF9A7A4E);
  static const Color summerFoliage = Color(0xFF5E8A4A);
  static const Color summerBloom = Color(0xFFE87F7F);

  static const Color autumnSky = Color(0xFFE4D2BC);
  static const Color autumnSoil = Color(0xFF7C5C3C);
  static const Color autumnFoliage = Color(0xFFC07A3E);
  static const Color autumnBloom = Color(0xFFB5533F);

  /// Falling leaf.
  static const Color autumnLeaf = Color(0xFFD98A3D);

  static const Color winterSky = Color(0xFFDCE6EC);
  static const Color winterSoil = Color(0xFFA9A197);

  /// Bare branches.
  static const Color winterFoliage = Color(0xFF9C8B7A);

  static const Color winterEvergreen = Color(0xFF3F6B4A);

  /// Muted, but enough that flowering plants still read as flowering.
  static const Color winterBloom = Color(0xFFCFBDBD);

  static const Color winterSnow = Color(0xFFFFFFFF);

  /// Zen's plot edges and decor. Doesn't change with the season.
  static const Color zenStone = Color(0xFF9A9A92);

  // --- Tropical and Wildflower ----------------------------------------------
  //
  // Same per-season set as above, plus a decor material each. Each theme
  // shifts the whole garden (tropical darker and greener, meadow paler and
  // drier) so it still reads as itself in every season.

  /// Tropical decor.
  static const Color tropicalTeak = Color(0xFF5A4636);

  static const Color tropicalSpringSky = Color(0xFFCFE3D2);
  static const Color tropicalSpringSoil = Color(0xFF4A3826);
  static const Color tropicalSpringFoliage = Color(0xFF4E8F5A);
  static const Color tropicalSpringBloom = Color(0xFFE86FA8);

  static const Color tropicalSummerSky = Color(0xFFAFD8BE);
  static const Color tropicalSummerSoil = Color(0xFF5A452E);
  static const Color tropicalSummerFoliage = Color(0xFF2F7A46);
  static const Color tropicalSummerBloom = Color(0xFFF2564B);

  static const Color tropicalAutumnSky = Color(0xFFD9D2B4);
  static const Color tropicalAutumnSoil = Color(0xFF4F3B28);
  static const Color tropicalAutumnFoliage = Color(0xFF3F7F52);
  static const Color tropicalAutumnBloom = Color(0xFFE0663C);

  /// Tropical winter stays green (it's a greenhouse).
  static const Color tropicalWinterSky = Color(0xFFC6D6DA);
  static const Color tropicalWinterSoil = Color(0xFF463628);
  static const Color tropicalWinterFoliage = Color(0xFF376B47);
  static const Color tropicalWinterEvergreen = Color(0xFF2E5C3C);
  static const Color tropicalWinterBloom = Color(0xFFD98CA8);

  /// Tropical particles.
  static const Color tropicalPetal = Color(0xFFF6C9DC);
  static const Color tropicalLeaf = Color(0xFFE0A254);

  /// Wildflower decor.
  static const Color meadowWood = Color(0xFFB09068);

  static const Color meadowSpringSky = Color(0xFFD6E9F5);
  static const Color meadowSpringSoil = Color(0xFF8A7550);
  static const Color meadowSpringFoliage = Color(0xFF93BE63);
  static const Color meadowSpringBloom = Color(0xFFEFA9C6);

  static const Color meadowSummerSky = Color(0xFFA9D2EE);
  static const Color meadowSummerSoil = Color(0xFFA98E5E);
  static const Color meadowSummerFoliage = Color(0xFF7FA24C);
  static const Color meadowSummerBloom = Color(0xFFF2C14E);

  static const Color meadowAutumnSky = Color(0xFFEADCC0);
  static const Color meadowAutumnSoil = Color(0xFF8E7048);
  static const Color meadowAutumnFoliage = Color(0xFFC9A24E);
  static const Color meadowAutumnBloom = Color(0xFFC46A45);

  static const Color meadowWinterSky = Color(0xFFE4EBEE);
  static const Color meadowWinterSoil = Color(0xFFB5AE9E);
  static const Color meadowWinterFoliage = Color(0xFFAFA286);
  static const Color meadowWinterEvergreen = Color(0xFF5C7A55);

  /// Picked to stay distinguishable from [meadowWinterSoil]; see the
  /// legibility check in `garden_theme_test.dart`.
  static const Color meadowWinterBloom = Color(0xFFC4A196);

  /// Meadow particles.
  static const Color meadowPetal = Color(0xFFF9DCE6);
  static const Color meadowLeaf = Color(0xFFDCA95A);
}
