import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/garden_skin.dart';
import '../../design/spacing.dart';
import '../../garden/season_providers.dart';
import '../../garden/theme_providers.dart';
import '../../settings/settings_providers.dart';

abstract final class ThemePickerKeys {
  static Key card(GardenTheme theme) => Key('themePicker.${theme.name}');
}

Future<void> showThemePicker(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ThemePickerScreen()),
    );

/// Pick one of the three biomes. Each card previews the real palette in
/// today's season. All are free.
class ThemePickerScreen extends ConsumerWidget {
  const ThemePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(gardenThemeProvider);
    final season = ref.watch(seasonProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Garden theme')),
      body: SafeArea(
        child: ListView(
          padding: Spacing.screenPadding,
          children: [
            for (final theme in GardenTheme.values) ...[
              _ThemeCard(
                theme: theme,
                skin: GardenSkin(theme: theme, season: season),
                selected: theme == chosen,
              ),
              const SizedBox(height: Spacing.md),
            ],
            const _SeasonNote(),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends ConsumerWidget {
  const _ThemeCard({
    required this.theme,
    required this.skin,
    required this.selected,
  });

  final GardenTheme theme;
  final GardenSkin skin;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final garden = GardenColors.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ThemePickerKeys.card(theme),
        onTap: () => _tapped(ref),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ThemeSwatch(skin: skin),
              const SizedBox(height: Spacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      theme.label,
                      style: text.titleMedium,
                      semanticsLabel: _spoken,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: Spacing.xs),
                    Icon(Icons.check_circle, color: garden.foliage),
                  ],
                ],
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                theme.blurb,
                style: text.bodySmall?.copyWith(color: garden.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Screen readers can't see the tick.
  String get _spoken => selected ? '${theme.label}, selected' : theme.label;

  /// Not awaited; settings are live before the write finishes. Read fresh so a
  /// stale value can't undo another change.
  void _tapped(WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    unawaited(
      controller.change(ref.read(settingsProvider).withGardenTheme(theme)),
    );
  }
}

/// A painted palette, not a real garden render (that would mean baking an
/// atlas per card). Shown in today's season so the preview is accurate.
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.skin});

  final GardenSkin skin;

  @override
  Widget build(BuildContext context) {
    final palette = skin.palette;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.md),
      child: AspectRatio(
        aspectRatio: 16 / 7,
        child: CustomPaint(
          painter: _SwatchPainter(
            sky: palette.sky,
            soil: palette.soil,
            foliage: palette.foliage,
            bloom: palette.bloom,
            decor: skin.biome.decor,
          ),
          // Decorative; the card text already names the theme.
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter({
    required this.sky,
    required this.soil,
    required this.foliage,
    required this.bloom,
    required this.decor,
  });

  final Color sky;
  final Color soil;
  final Color foliage;
  final Color bloom;
  final Color decor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = sky);

    // Ground band at roughly the garden's default horizon.
    final horizon = size.height * 0.62;
    canvas.drawRect(
      Rect.fromLTRB(0, horizon, size.width, size.height),
      Paint()..color = soil.withValues(alpha: 0.55),
    );

    // One isometric plot edged in the biome's decor colour, like the atlas.
    final centre = Offset(size.width / 2, (horizon + size.height) / 2);
    final plot = size.width * 0.22;
    final diamond = Path()
      ..moveTo(centre.dx, centre.dy - plot / 2)
      ..lineTo(centre.dx + plot, centre.dy)
      ..lineTo(centre.dx, centre.dy + plot / 2)
      ..lineTo(centre.dx - plot, centre.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = soil.withValues(alpha: 0.42));
    canvas.drawPath(
      diamond,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.02
        ..color = decor,
    );

    // One plant in leaf, one in flower.
    canvas.drawCircle(
      Offset(size.width * 0.32, horizon - size.height * 0.10),
      size.height * 0.16,
      Paint()..color = foliage,
    );
    canvas.drawCircle(
      Offset(size.width * 0.70, horizon - size.height * 0.06),
      size.height * 0.11,
      Paint()..color = bloom,
    );
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.sky != sky ||
      old.soil != soil ||
      old.foliage != foliage ||
      old.bloom != bloom ||
      old.decor != decor;
}

/// Explains that colours also shift with the season, so an amber garden in
/// November isn't mistaken for the theme.
class _SeasonNote extends ConsumerWidget {
  const _SeasonNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final season = ref.watch(seasonProvider);

    return Text(
      'Every theme turns with the seasons. These show how they look in '
      '${season.label.toLowerCase()}.',
      textAlign: TextAlign.center,
      style: theme.textTheme.labelSmall
          ?.copyWith(color: GardenColors.of(context).textSecondary),
    );
  }
}
