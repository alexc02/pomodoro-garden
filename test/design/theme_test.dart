import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_garden/src/design/garden_colors.dart';
import 'package:pomodoro_garden/src/design/palette.dart';
import 'package:pomodoro_garden/src/design/theme.dart';
import 'package:pomodoro_garden/src/design/typography.dart';

void main() {
  group('both themes resolve', () {
    for (final (name, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      test('$name carries the garden colours and the type ramp', () {
        expect(theme.extension<GardenColors>(), isNotNull);
        expect(theme.textTheme.displayLarge?.fontFamily,
            GardenTypography.fontFamily);
        expect(theme.textTheme.displayLarge?.fontWeight,
            GardenTypography.headingWeight);
        expect(theme.textTheme.bodyMedium?.fontWeight,
            GardenTypography.bodyWeight);
      });

      test('$name writes no colour of its own outside the palette', () {
        // Every colour the scheme resolves has to trace back to a token, or
        // the "no hardcoded colours" rule is already broken at the theme.
        // A list rather than a set: several tokens share a value (white serves
        // as onPrimary, onError and the light surface), which is fine for a
        // membership check but a duplicate in a set literal.
        final tokens = <Color>[
          Palette.primary,
          Palette.onPrimary,
          Palette.soil,
          Palette.skyDay,
          Palette.skyGoldenHour,
          Palette.accentBloom,
          Palette.backgroundDark,
          Palette.backgroundLight,
          Palette.surfaceLight,
          Palette.surfaceDark,
          Palette.textPrimary,
          Palette.textSecondary,
          Palette.textPrimaryDark,
          Palette.textSecondaryDark,
          Palette.error,
          Palette.onError,
          Palette.errorDark,
          Palette.onErrorDark,
        ];

        final scheme = theme.colorScheme;
        for (final colour in [
          scheme.primary,
          scheme.onPrimary,
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          scheme.secondary,
          scheme.onSecondary,
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          scheme.tertiary,
          scheme.onTertiary,
          scheme.error,
          scheme.onError,
          scheme.surface,
          scheme.onSurface,
          scheme.onSurfaceVariant,
          scheme.outline,
        ]) {
          expect(tokens, contains(colour));
        }

        expect(tokens, contains(theme.scaffoldBackgroundColor));
      });

      test('$name gives every text style a colour', () {
        for (final style in [
          theme.textTheme.displayLarge,
          theme.textTheme.headlineMedium,
          theme.textTheme.titleMedium,
          theme.textTheme.bodyMedium,
          theme.textTheme.bodySmall,
          theme.textTheme.labelSmall,
        ]) {
          expect(style?.color, isNotNull);
        }
      });
    }

    test('light uses the light canvas, dark uses the §5.1 dark background', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(
        AppTheme.light.scaffoldBackgroundColor,
        Palette.backgroundLight,
      );

      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(
        AppTheme.dark.scaffoldBackgroundColor,
        Palette.backgroundDark,
        reason: 'PRD §5.1 names #1C2B1C as the dark-mode background.',
      );
    });

    test('both keep garden green as the primary', () {
      expect(AppTheme.light.colorScheme.primary, Palette.primary);
      expect(AppTheme.dark.colorScheme.primary, Palette.primary);
    });
  });

  group('the §5.1 palette', () {
    test('is reachable in full through the theme', () {
      // Every colour §5.1 names, and where a screen gets it from. If a later
      // ticket needs a §5.1 colour that is not on this list, it belongs on the
      // theme rather than hardcoded at the call site.
      const light = GardenColors.light;
      const dark = GardenColors.dark;

      expect(AppTheme.light.colorScheme.primary, Palette.primary);
      expect(light.soil, Palette.soil);
      expect(light.skyDay, Palette.skyDay);
      expect(light.skyGoldenHour, Palette.skyGoldenHour);
      expect(light.bloom, Palette.accentBloom);
      expect(light.textPrimary, Palette.textPrimary);
      expect(light.textSecondary, Palette.textSecondary);
      expect(AppTheme.dark.scaffoldBackgroundColor, Palette.backgroundDark);

      // The illustrated world keeps its colours in dark mode; only text moves.
      expect(dark.soil, Palette.soil);
      expect(dark.skyDay, Palette.skyDay);
      expect(dark.skyGoldenHour, Palette.skyGoldenHour);
      expect(dark.bloom, Palette.accentBloom);
      expect(dark.textPrimary, Palette.textPrimaryDark);
      expect(dark.textSecondary, Palette.textSecondaryDark);
    });

    test('holds the exact hex values from the PRD', () {
      expect(Palette.primary, const Color(0xFF6B8E5A));
      expect(Palette.soil, const Color(0xFF8B6F47));
      expect(Palette.skyDay, const Color(0xFFB8D4E8));
      expect(Palette.skyGoldenHour, const Color(0xFFF5C99B));
      expect(Palette.accentBloom, const Color(0xFFE89B9B));
      expect(Palette.backgroundDark, const Color(0xFF1C2B1C));
      expect(Palette.textPrimary, const Color(0xFF2D3A2D));
      expect(Palette.textSecondary, const Color(0xFF6B7B6B));
    });
  });

  group('GardenColors', () {
    test('lerps every channel', () {
      final midpoint = GardenColors.light.lerp(GardenColors.dark, 1);

      expect(midpoint.textPrimary, GardenColors.dark.textPrimary);
      expect(midpoint.textSecondary, GardenColors.dark.textSecondary);
    });

    test('copyWith replaces only what it is given', () {
      final tweaked = GardenColors.light.copyWith(bloom: Palette.soil);

      expect(tweaked.bloom, Palette.soil);
      expect(tweaked.soil, GardenColors.light.soil);
      expect(tweaked.textPrimary, GardenColors.light.textPrimary);
    });

    testWidgets('of(context) throws outside a garden theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              expect(
                () => GardenColors.of(context),
                throwsA(isA<StateError>()),
                reason: 'Falling back to the light palette here would render '
                    'unreadable text on a dark screen rather than fail.',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('of(context) reads the theme in force', (tester) async {
      late GardenColors resolved;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              resolved = GardenColors.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved.textPrimary, Palette.textPrimaryDark);
    });
  });
}
