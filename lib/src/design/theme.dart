import 'package:flutter/material.dart';

import 'garden_colors.dart';
import 'palette.dart';
import 'spacing.dart';
import 'typography.dart';

/// Light and dark [ThemeData] built from the design tokens.
///
/// Schemes are written out by hand because `ColorScheme.fromSeed` would
/// replace the palette with its own approximations. This is the app chrome
/// theme; not to be confused with the domain's `GardenTheme` (the user's
/// biome choice).
abstract final class AppTheme {
  static ThemeData get light => _build(_lightScheme, GardenColors.light);

  static ThemeData get dark => _build(_darkScheme, GardenColors.dark);

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Palette.moss,
    onPrimary: Palette.backgroundLight,
    primaryContainer: Palette.mist,
    onPrimaryContainer: Palette.textPrimary,
    secondary: Palette.marigold,
    onSecondary: Palette.textPrimary,
    secondaryContainer: Palette.skyGoldenHour,
    onSecondaryContainer: Palette.textPrimary,
    tertiary: Palette.soil,
    onTertiary: Palette.onPrimary,
    error: Palette.error,
    onError: Palette.onError,
    surface: Palette.surfaceLight,
    onSurface: Palette.textPrimary,
    onSurfaceVariant: Palette.textSecondary,
    outline: Palette.textSecondary,
  );

  // Marigold primary: moss disappears on the dark canvas.
  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Palette.marigold,
    onPrimary: Palette.moss,
    primaryContainer: Palette.surfaceDark,
    onPrimaryContainer: Palette.textPrimaryDark,
    secondary: Palette.marigold,
    onSecondary: Palette.moss,
    secondaryContainer: Palette.soil,
    onSecondaryContainer: Palette.textPrimaryDark,
    tertiary: Palette.soil,
    onTertiary: Palette.textPrimaryDark,
    error: Palette.errorDark,
    onError: Palette.onErrorDark,
    surface: Palette.surfaceDark,
    onSurface: Palette.textPrimaryDark,
    onSurfaceVariant: Palette.textSecondaryDark,
    outline: Palette.textSecondaryDark,
  );

  static ThemeData _build(ColorScheme scheme, GardenColors garden) {
    final textTheme = _textTheme(garden);

    return ThemeData(
      colorScheme: scheme,
      brightness: scheme.brightness,
      fontFamily: GardenTypography.fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.brightness == Brightness.dark
          ? Palette.backgroundDark
          : Palette.backgroundLight,
      extensions: [garden],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: garden.textPrimary,
        titleTextStyle: textTheme.titleMedium,
      ),
      // Moss tab bar in both modes; selection is marigold plus weight
      // instead of the stock M3 pill.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Palette.moss,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? Palette.marigold : Palette.mist,
            fontWeight: selected
                ? GardenTypography.headingWeight
                : GardenTypography.bodyWeight,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? Palette.marigold : Palette.mist,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: Radii.paperMd),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: Radii.paperSm),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          textStyle: textTheme.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: Radii.paperSmMirrored,
          ),
          side: BorderSide(color: scheme.primary, width: 2),
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          textStyle: textTheme.titleMedium,
        ),
      ),
      // Thin track, no value bubble (the row already shows the value).
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primary.withValues(alpha: 0.16),
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: Spacing.xs,
        showValueIndicator: ShowValueIndicator.never,
      ),
      // Selection is fill plus a tick, not colour alone, for colour-blind
      // users.
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: scheme.primary.withValues(alpha: 0.16),
        checkmarkColor: scheme.primary,
        side: BorderSide(color: garden.textSecondary.withValues(alpha: 0.35)),
        shape: const RoundedRectangleBorder(borderRadius: Radii.paperSm),
        labelStyle: textTheme.bodyMedium,
        secondaryLabelStyle: textTheme.bodyMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
      ),
    );
  }

  static TextTheme _textTheme(GardenColors garden) {
    final primary = garden.textPrimary;
    final secondary = garden.textSecondary;

    return TextTheme(
      displayLarge: GardenTypography.displayLarge.copyWith(color: primary),
      headlineMedium: GardenTypography.headlineMedium.copyWith(color: primary),
      titleMedium: GardenTypography.titleMedium.copyWith(color: primary),
      bodyMedium: GardenTypography.bodyMedium.copyWith(color: primary),
      bodySmall: GardenTypography.bodySmall.copyWith(color: secondary),
      labelSmall: GardenTypography.labelSmall.copyWith(color: secondary),
    );
  }
}
