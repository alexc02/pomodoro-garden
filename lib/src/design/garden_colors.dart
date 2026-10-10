import 'package:flutter/material.dart';

import 'palette.dart';

/// The garden-specific colours that have no home in Material's [ColorScheme].
///
/// Soil, sky and bloom describe the illustrated world rather than UI chrome, so
/// they hang off the theme as an extension and stay reachable the same way
/// every other colour is: `GardenColors.of(context)`. REQ-019 reseasons the
/// garden by substituting one of these over the garden's subtree, and touches
/// no call site to do it — see `SeasonalGarden`.
@immutable
final class GardenColors extends ThemeExtension<GardenColors> {
  const GardenColors({
    required this.soil,
    required this.decor,
    required this.skyDay,
    required this.skyGoldenHour,
    required this.bloom,
    required this.foliage,
    required this.evergreenFoliage,
    required this.textPrimary,
    required this.textSecondary,
  });

  /// Plot beds and the garden floor.
  final Color soil;

  /// The material a garden's furniture is cut from: the edge of a plot today,
  /// and ticket 20's lanterns, benches and birdbaths when they land.
  ///
  /// **The one garden colour a season does not move.** Sky, soil, foliage and
  /// bloom all turn with the calendar; stone does not, and neither does teak or
  /// a silvered fence rail. Holding the material still is what keeps REQ-034's
  /// three themes telling themselves apart in all four seasons — see
  /// `ThemePalette.decor`.
  final Color decor;

  /// The garden's daytime backdrop.
  final Color skyDay;

  /// The warm backdrop used for session-complete moments.
  final Color skyGoldenHour;

  /// Reward accent: flowering plants, milestones, celebration.
  final Color bloom;

  /// The green a plant's leaves are drawn in.
  ///
  /// The same value as the scheme's primary in every theme the app ships, and a
  /// field of its own all the same: REQ-019 turns the garden's leaves orange in
  /// October and bare in January without turning the app's buttons orange with
  /// them. A season swaps this; nothing a season does reaches `ColorScheme`.
  final Color foliage;

  /// The green a plant that keeps its leaves is drawn in.
  ///
  /// Equal to [foliage] for three seasons of the year, and the whole of
  /// REQ-019's "evergreens retain color" for the fourth. Which species count as
  /// evergreen is `plant_palettes.dart`'s answer, not this one's — this is only
  /// the colour they hold.
  final Color evergreenFoliage;

  /// Body and heading text on this theme's surfaces.
  final Color textPrimary;

  /// Captions, labels and disabled text on this theme's surfaces.
  final Color textSecondary;

  static const GardenColors light = GardenColors(
    soil: Palette.soil,
    decor: Palette.zenStone,
    skyDay: Palette.skyDay,
    skyGoldenHour: Palette.skyGoldenHour,
    bloom: Palette.accentBloom,
    foliage: Palette.primary,
    evergreenFoliage: Palette.primary,
    textPrimary: Palette.textPrimary,
    textSecondary: Palette.textSecondary,
  );

  /// Dark mode keeps soil, sky and bloom at their §5.1 values — the garden's
  /// own colours are the illustration and should not shift with the UI
  /// brightness — and swaps only the text colours, which must stay legible
  /// against [Palette.backgroundDark].
  static const GardenColors dark = GardenColors(
    soil: Palette.soil,
    decor: Palette.zenStone,
    skyDay: Palette.skyDay,
    skyGoldenHour: Palette.skyGoldenHour,
    bloom: Palette.accentBloom,
    foliage: Palette.primary,
    evergreenFoliage: Palette.primary,
    textPrimary: Palette.textPrimaryDark,
    textSecondary: Palette.textSecondaryDark,
  );

  /// The [GardenColors] for the enclosing theme.
  ///
  /// Throws if the theme has no [GardenColors] — that means the widget is
  /// outside `PomodoroGardenApp`, which is a wiring bug, not a case to paper
  /// over with a default that silently renders the light palette on a dark
  /// screen. Throws in release too, for the same reason `MediaQuery.of` does:
  /// an assert would let the broken build ship.
  static GardenColors of(BuildContext context) {
    final colors = Theme.of(context).extension<GardenColors>();
    if (colors == null) {
      throw StateError(
        'No GardenColors in this theme. Build the theme with AppTheme.light '
        'or AppTheme.dark, or wrap this subtree in one of them.',
      );
    }
    return colors;
  }

  @override
  GardenColors copyWith({
    Color? soil,
    Color? decor,
    Color? skyDay,
    Color? skyGoldenHour,
    Color? bloom,
    Color? foliage,
    Color? evergreenFoliage,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return GardenColors(
      soil: soil ?? this.soil,
      decor: decor ?? this.decor,
      skyDay: skyDay ?? this.skyDay,
      skyGoldenHour: skyGoldenHour ?? this.skyGoldenHour,
      bloom: bloom ?? this.bloom,
      foliage: foliage ?? this.foliage,
      evergreenFoliage: evergreenFoliage ?? this.evergreenFoliage,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  GardenColors lerp(covariant GardenColors? other, double t) {
    if (other == null) return this;
    return GardenColors(
      soil: Color.lerp(soil, other.soil, t)!,
      decor: Color.lerp(decor, other.decor, t)!,
      skyDay: Color.lerp(skyDay, other.skyDay, t)!,
      skyGoldenHour: Color.lerp(skyGoldenHour, other.skyGoldenHour, t)!,
      bloom: Color.lerp(bloom, other.bloom, t)!,
      foliage: Color.lerp(foliage, other.foliage, t)!,
      evergreenFoliage:
          Color.lerp(evergreenFoliage, other.evergreenFoliage, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }

  /// Two [GardenColors] are the same when every colour in them is.
  ///
  /// Value equality because this is a value: ticket 14 builds a new one per
  /// frame of a season crossfade, and without this `ThemeData ==` would report
  /// two identical themes as different — which is the sort of thing that turns
  /// a settled screen into one that rebuilds forever.
  @override
  bool operator ==(Object other) =>
      other is GardenColors &&
      other.soil == soil &&
      other.decor == decor &&
      other.skyDay == skyDay &&
      other.skyGoldenHour == skyGoldenHour &&
      other.bloom == bloom &&
      other.foliage == foliage &&
      other.evergreenFoliage == evergreenFoliage &&
      other.textPrimary == textPrimary &&
      other.textSecondary == textSecondary;

  @override
  int get hashCode => Object.hash(
        soil,
        decor,
        skyDay,
        skyGoldenHour,
        bloom,
        foliage,
        evergreenFoliage,
        textPrimary,
        textSecondary,
      );
}
