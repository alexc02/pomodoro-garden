import 'package:flutter/material.dart';

import 'palette.dart';

/// Garden colours that don't fit [ColorScheme]. Seasons swap in a different
/// instance over the garden subtree (see `SeasonalGarden`).
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

  /// Plot edges and decor items. The only garden colour seasons don't change
  /// (see `ThemePalette.decor`).
  final Color decor;

  final Color skyDay;

  /// Backdrop for session-complete moments.
  final Color skyGoldenHour;

  /// Reward accent: flowering plants, milestones, celebration.
  final Color bloom;

  /// Leaf colour. Same as the scheme primary by default, but separate so
  /// seasons can change leaves without touching buttons.
  final Color foliage;

  /// Evergreen leaf colour. Equals [foliage] except in winter. Which species
  /// are evergreen is decided in `plant_palettes.dart`.
  final Color evergreenFoliage;

  final Color textPrimary;

  /// Captions, labels, disabled text.
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

  /// Same garden colours as light; only the text changes.
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

  /// Throws (in release too) if the theme has no [GardenColors]; that's a
  /// wiring bug, not something to default around.
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

  /// Value equality, so `ThemeData ==` works when a season crossfade builds
  /// a new instance each frame.
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
