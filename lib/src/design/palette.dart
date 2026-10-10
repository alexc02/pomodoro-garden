import 'package:flutter/painting.dart';

/// The raw colour palette from PRD §5.1.
///
/// These are the literals, and the only place they appear in the codebase.
/// Screens read semantic colours off the theme (`Theme.of(context).colorScheme`
/// and [GardenColors]) rather than reaching in here, so a repaint of the
/// palette does not mean a sweep of every widget.
abstract final class Palette {
  /// Garden green. The primary brand colour: healthy foliage.
  static const Color primary = Color(0xFF6B8E5A);

  /// Tilled earth. Plot beds and the garden floor.
  static const Color soil = Color(0xFF8B6F47);

  /// Daytime sky, and the light-mode canvas behind the garden.
  static const Color skyDay = Color(0xFFB8D4E8);

  /// Golden hour sky. Session-complete moments and warm accents.
  static const Color skyGoldenHour = Color(0xFFF5C99B);

  /// Bloom pink. Reserved for reward moments — a flowering plant, a milestone.
  static const Color accentBloom = Color(0xFFE89B9B);

  /// The dark-mode canvas: green-black, so night in the garden still reads as
  /// a garden rather than a generic dark UI.
  static const Color backgroundDark = Color(0xFF1C2B1C);

  /// Primary text on light surfaces.
  static const Color textPrimary = Color(0xFF2D3A2D);

  /// Secondary text on light surfaces: captions, labels, disabled states.
  static const Color textSecondary = Color(0xFF6B7B6B);

  // --- Derived tokens -------------------------------------------------------
  //
  // §5.1 names a dark-mode background but no light-mode one, and gives text
  // colours only for light surfaces. The four below fill those gaps so both
  // themes resolve. They are marked out here so a future design pass knows
  // which values came from the PRD and which this ticket chose.

  /// Light-mode canvas: warm off-white, a shade of paper rather than pure
  /// white, to sit with the watercolour illustration style.
  static const Color backgroundLight = Color(0xFFF7F5EF);

  /// Raised surfaces in light mode — cards, sheets, the tab bar.
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Raised surfaces in dark mode: one step up from [backgroundDark].
  static const Color surfaceDark = Color(0xFF263826);

  /// Primary text on dark surfaces.
  static const Color textPrimaryDark = Color(0xFFE8EFE6);

  /// Secondary text on dark surfaces.
  static const Color textSecondaryDark = Color(0xFFA3B3A0);

  /// Text and icons on a filled [primary] surface.
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Error colours. §5.1 has no destructive tone — the palette is deliberately
  // all warmth — so these are Material's defaults, kept only for the states
  // Flutter requires a colour for.
  static const Color error = Color(0xFFB3261E);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorDark = Color(0xFFF2B8B5);
  static const Color onErrorDark = Color(0xFF601410);

  // --- REQ-019's seasons ----------------------------------------------------
  //
  // Five colours a season, and they are the *garden's* colours rather than the
  // app's: sky, soil, foliage and bloom are what `GardenColors` carries, and
  // the fifth is whatever drifts down through the air. §5.1 names none of them,
  // so like the derived tokens above they are this ticket's choices — kept in
  // one block, and each a shift of the season next to it rather than a fresh
  // idea. Nothing outside `season_palette.dart` reads these.
  //
  // The base tokens are the summer ones by construction: §5.1's palette is a
  // garden in full leaf, so summer sits closest to it and the other three are
  // measured against it.

  /// Spring: a washed morning blue behind fresh growth.
  static const Color springSky = Color(0xFFCBE3F2);
  static const Color springSoil = Color(0xFF7A6244);
  static const Color springFoliage = Color(0xFF8FB86A);
  static const Color springBloom = Color(0xFFF3C0CE);

  /// Cherry blossom on its way down.
  static const Color springPetal = Color(0xFFF7D3DE);

  /// Summer: §5.1's own garden, a shade brighter overhead.
  static const Color summerSky = Color(0xFF9CCBE8);
  static const Color summerSoil = Color(0xFF9A7A4E);
  static const Color summerFoliage = Color(0xFF5E8A4A);
  static const Color summerBloom = Color(0xFFE87F7F);

  /// Autumn: the light goes amber before the leaves do.
  static const Color autumnSky = Color(0xFFE4D2BC);
  static const Color autumnSoil = Color(0xFF7C5C3C);
  static const Color autumnFoliage = Color(0xFFC07A3E);
  static const Color autumnBloom = Color(0xFFB5533F);

  /// A leaf, mid-fall.
  static const Color autumnLeaf = Color(0xFFD98A3D);

  /// Winter: a flat cold sky over frosted ground.
  static const Color winterSky = Color(0xFFDCE6EC);
  static const Color winterSoil = Color(0xFFA9A197);

  /// Bare wood. REQ-019's "bare branches", as the colour a plant that has
  /// dropped its leaves is drawn in.
  static const Color winterFoliage = Color(0xFF9C8B7A);

  /// REQ-019's "evergreens retain color": the one green left in the garden in
  /// January, and deliberately colder and deeper than any of the other three
  /// seasons' foliage.
  static const Color winterEvergreen = Color(0xFF3F6B4A);

  /// What little colour is left on a plant in winter: frost-touched rather than
  /// gone, so a flowering plant is still recognisable as one.
  static const Color winterBloom = Color(0xFFCFBDBD);

  /// Snow.
  static const Color winterSnow = Color(0xFFFFFFFF);

  /// Zen's stone: the material its plot edges and ticket 20's decor are cut
  /// from, and the one colour in a theme that does not move with the season.
  ///
  /// A lantern is the same stone in July and January. Holding the material
  /// still through the year is what keeps a theme recognisable in all four of
  /// them — see `ThemePalette.decor`.
  static const Color zenStone = Color(0xFF9A9A92);

  // --- REQ-034's other two biomes -------------------------------------------
  //
  // The same five colours a season that the block above holds, twice over, plus
  // one material apiece. §5.1 names none of them: its palette is *Zen's summer*
  // by construction, so these two themes are measured against that the same way
  // the seasons are measured against summer.
  //
  // Each theme is a shift of the whole garden rather than a recolour of one
  // part of it — a greenhouse is darker underfoot and greener overhead in every
  // month, a meadow is paler and drier in every month — which is what lets the
  // two systems compose: the season still moves all five, and the theme still
  // reads as itself at every point in the year.

  /// Tropical: dark teak, wet from the misting.
  static const Color tropicalTeak = Color(0xFF5A4636);

  /// Tropical spring: misted glass over new growth.
  static const Color tropicalSpringSky = Color(0xFFCFE3D2);
  static const Color tropicalSpringSoil = Color(0xFF4A3826);
  static const Color tropicalSpringFoliage = Color(0xFF4E8F5A);
  static const Color tropicalSpringBloom = Color(0xFFE86FA8);

  /// Tropical summer: the hottest the glasshouse gets, and the most saturated.
  static const Color tropicalSummerSky = Color(0xFFAFD8BE);
  static const Color tropicalSummerSoil = Color(0xFF5A452E);
  static const Color tropicalSummerFoliage = Color(0xFF2F7A46);
  static const Color tropicalSummerBloom = Color(0xFFF2564B);

  /// Tropical autumn: amber light on the outside of the glass, and nothing
  /// inside it turning.
  static const Color tropicalAutumnSky = Color(0xFFD9D2B4);
  static const Color tropicalAutumnSoil = Color(0xFF4F3B28);
  static const Color tropicalAutumnFoliage = Color(0xFF3F7F52);
  static const Color tropicalAutumnBloom = Color(0xFFE0663C);

  /// Tropical winter: cold light through condensation, over a garden that is
  /// still green because the glass is what the season cannot get through.
  static const Color tropicalWinterSky = Color(0xFFC6D6DA);
  static const Color tropicalWinterSoil = Color(0xFF463628);
  static const Color tropicalWinterFoliage = Color(0xFF376B47);
  static const Color tropicalWinterEvergreen = Color(0xFF2E5C3C);
  static const Color tropicalWinterBloom = Color(0xFFD98CA8);

  /// What falls on the outside of the glass.
  static const Color tropicalPetal = Color(0xFFF6C9DC);
  static const Color tropicalLeaf = Color(0xFFE0A254);

  /// Wildflower: the silvered wood of a fence nobody has painted in years.
  static const Color meadowWood = Color(0xFFB09068);

  /// Meadow spring: wide sky over the first green.
  static const Color meadowSpringSky = Color(0xFFD6E9F5);
  static const Color meadowSpringSoil = Color(0xFF8A7550);
  static const Color meadowSpringFoliage = Color(0xFF93BE63);
  static const Color meadowSpringBloom = Color(0xFFEFA9C6);

  /// Meadow summer: grass going gold, and colour scattered right through it.
  static const Color meadowSummerSky = Color(0xFFA9D2EE);
  static const Color meadowSummerSoil = Color(0xFFA98E5E);
  static const Color meadowSummerFoliage = Color(0xFF7FA24C);
  static const Color meadowSummerBloom = Color(0xFFF2C14E);

  /// Meadow autumn: straw and seed heads.
  static const Color meadowAutumnSky = Color(0xFFEADCC0);
  static const Color meadowAutumnSoil = Color(0xFF8E7048);
  static const Color meadowAutumnFoliage = Color(0xFFC9A24E);
  static const Color meadowAutumnBloom = Color(0xFFC46A45);

  /// Meadow winter: bleached stalks over frozen ground, with the one green that
  /// stays.
  static const Color meadowWinterSky = Color(0xFFE4EBEE);
  static const Color meadowWinterSoil = Color(0xFFB5AE9E);
  static const Color meadowWinterFoliage = Color(0xFFAFA286);
  static const Color meadowWinterEvergreen = Color(0xFF5C7A55);

  /// A rosehip, and the one thing in a January meadow with any colour left.
  ///
  /// Chosen against the frozen ground rather than for its own sake: the first
  /// value tried here was a bleached grey-pink, which measured *less*
  /// separable from this theme's winter soil than any colour in the free
  /// theme — a flower that disappeared into the plot it was standing on. See
  /// the legibility floor in `garden_theme_test.dart`.
  static const Color meadowWinterBloom = Color(0xFFC4A196);

  /// What blows across a meadow.
  static const Color meadowPetal = Color(0xFFF9DCE6);
  static const Color meadowLeaf = Color(0xFFDCA95A);
}
