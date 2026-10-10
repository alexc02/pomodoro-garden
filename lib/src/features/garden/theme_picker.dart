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

/// The picker's controls, by name — what a test reaches for rather than "the
/// second card".
abstract final class ThemePickerKeys {
  /// One card per biome.
  static Key card(GardenTheme theme) => Key('themePicker.${theme.name}');
}

/// Opens REQ-034's theme picker.
Future<void> showThemePicker(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ThemePickerScreen()),
    );

/// REQ-034: which of the three biomes the garden is dressed in.
///
/// **Every theme is previewed, and every one of them can be applied.** A card
/// shows the real palette, in today's real season, at the same size as the one
/// the user is standing in — nothing is blurred, greyed out or behind a lock.
/// An earlier draft sold two of the three; see `docs/adr/0021-…`.
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

/// One biome, previewed and offered.
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

  /// What a screen reader says about this card, since the tick is not a thing
  /// it can read.
  String get _spoken => selected ? '${theme.label}, selected' : theme.label;

  /// Dresses the garden in this theme.
  ///
  /// Not awaited, for the reason the settings screen does not await its own:
  /// the value is live before this returns and the write reports its own
  /// failures. Read fresh rather than closed over, so a theme picked in the
  /// same frame as another setting changed cannot undo it.
  void _tapped(WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    unawaited(
      controller.change(ref.read(settingsProvider).withGardenTheme(theme)),
    );
  }
}

/// A garden's worth of colour, at the size of a card.
///
/// Not a rendering of the real garden, and deliberately: the garden is an
/// atlas, a projection and up to two hundred plants, and baking one per card
/// would cost three textures to show three colour schemes. What a user is
/// choosing between here is a *palette*, so the preview is the palette — sky
/// behind, ground across the bottom, a plot edged in the biome's own material,
/// and two plants' worth of foliage and bloom standing on it.
///
/// It is drawn in **today's season**, which is what makes the picker honest.
/// A meadow previewed in permanent July would be a promise the app breaks in
/// November.
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
          // Decorative: the card already says the theme's name and its blurb in
          // words, so a screen reader has nothing to gain from this and would
          // only have to walk past it.
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// The five colours of a biome, arranged as a garden.
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

    // The ground: a band across the bottom third, which is where the garden's
    // horizon sits at the default zoom.
    final horizon = size.height * 0.62;
    canvas.drawRect(
      Rect.fromLTRB(0, horizon, size.width, size.height),
      Paint()..color = soil.withValues(alpha: 0.55),
    );

    // One plot, in the isometric diamond the garden actually uses, edged in the
    // biome's material — the same pairing `GardenAtlas` bakes.
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

    // Two plants: one in leaf and one in flower, so the swatch shows the two
    // colours a garden of this biome is mostly made of.
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

/// The line at the bottom of the picker.
///
/// **Says what the two systems do together**, because a user who has just
/// noticed their garden is amber needs to know that is November rather than the
/// theme they chose. REQ-034 and REQ-019 compose, and this is the one sentence
/// in the app that says so out loud.
class _SeasonNote extends ConsumerWidget {
  const _SeasonNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final season = ref.watch(seasonProvider);

    return Text(
      'Every theme changes with the seasons. These are previewed as they look '
      'in ${season.label.toLowerCase()}.',
      textAlign: TextAlign.center,
      style: theme.textTheme.labelSmall
          ?.copyWith(color: GardenColors.of(context).textSecondary),
    );
  }
}
