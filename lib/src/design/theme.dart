import 'package:flutter/material.dart';

import 'garden_colors.dart';
import 'palette.dart';
import 'spacing.dart';
import 'typography.dart';

/// Builds the app's light and dark [ThemeData] from the design tokens.
///
/// The schemes are written out rather than seeded from a single colour:
/// `ColorScheme.fromSeed` would derive a tonal palette and quietly replace the
/// §5.1 hexes with its own approximations of them.
///
/// **`AppTheme` rather than `GardenTheme`**, which is REQ-034's word for
/// something else entirely: this is the app's chrome — the timer's ring, the
/// tab bar, the settings sliders — and it follows the phone's brightness. A
/// *garden* theme is a biome the user chose, it reaches the garden's subtree
/// and nothing above it, and it is `GardenTheme` in the domain.
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

  // Marigold rather than moss as the primary: moss on the green-black canvas
  // is a control nobody can find.
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
      // The tab bar is a strip of moss paper in both themes, and selection is
      // marigold plus weight rather than a tinted pill — the pill indicator is
      // the most recognisable stock part of a Material 3 app.
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
      // The quieter control beside a filled one: the same paper, outlined.
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
      // Settings sliders. A thin track in the garden green, and no value
      // bubble — the row above every slider already shows the value, and a
      // bubble popping up under the thumb is the opposite of calm.
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primary.withValues(alpha: 0.16),
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: Spacing.xs,
        showValueIndicator: ShowValueIndicator.never,
      ),
      // The preset chips: small cut tabs of paper, with the buttons' uneven
      // corners. Selection reads as a fill plus a tick rather than a colour
      // change alone, which keeps it legible to anyone who cannot separate the
      // selected green from the unselected outline.
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
