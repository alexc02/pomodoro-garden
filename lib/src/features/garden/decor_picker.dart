import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';
import '../../garden/decor_providers.dart';
import '../../garden/decor_sprite.dart';
import '../../garden/plant_painter.dart';
import '../../garden/plant_palettes.dart';
import '../../garden/plant_providers.dart';
import '../../garden/shelf_providers.dart';

abstract final class DecorKeys {
  /// Enters arranging mode, on the garden's bar.
  static const Key arrange = Key('decor.arrange');

  static const Key done = Key('decor.done');

  /// The bar's hint text.
  static const Key guidance = Key('decor.guidance');

  /// Removes the held object from the garden. Decor only.
  static const Key remove = Key('decor.remove');

  /// Moves the held plant to the shelf. Plants only.
  static const Key shelve = Key('decor.shelve');

  /// Drops whatever is held, plant or object, without leaving arranging.
  static const Key putDown = Key('decor.putDown');

  static Key kind(DecorKind kind) => Key('decor.kind.${kind.name}');

  /// A species with plants on the shelf, offered in the picker.
  static Key shelved(PlantSpecies species) =>
      Key('decor.shelved.${species.name}');
}

/// Opens the picker for [plot] and places whatever is chosen: a new object,
/// or a plant from the shelf. Plot first, choice second, so taps on the
/// garden are never ambiguous. Dismissing places nothing.
Future<void> showDecorPicker(
  BuildContext context,
  WidgetRef ref,
  GardenPlot plot,
) async {
  // A [DecorKind] to place, or a shelved [Plant] to bring back.
  final chosen = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _DecorPicker(),
  );

  if (chosen == null || !context.mounted) return;
  final arranger = ref.read(gardenArrangerProvider.notifier);
  switch (chosen) {
    case final DecorKind kind:
      await arranger.place(kind, plot);
    case final Plant plant:
      await arranger.replant(plant, plot);
  }
}

class _DecorPicker extends ConsumerWidget {
  const _DecorPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final colors = GardenColors.of(context);
    // Species with something stored, in shelf order. Empty for the frame or
    // so the shelf takes to load.
    final stored = [
      for (final row in ref.watch(shelfProvider).value?.rows ?? <ShelfRow>[])
        for (final spot in row.spots)
          if (spot.stored.isNotEmpty) spot,
    ];

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, Spacing.lg),
        children: [
          // At the top and scrolling sideways, so it's visible straight away
          // and a full shelf doesn't push the objects off the sheet.
          if (stored.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: Text('From your shelf', style: text.titleLarge),
            ),
            const SizedBox(height: Spacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final spot in stored) _ShelvedChoice(spot)],
              ),
            ),
            const SizedBox(height: Spacing.md),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Text(
              stored.isEmpty ? 'Place something here' : 'Or something new',
              style: text.titleLarge,
            ),
          ),
          const SizedBox(height: Spacing.md),
          for (final kind in DecorKind.values)
            ListTile(
              key: DecorKeys.kind(kind),
              // The actual sprite, not a generic icon.
              leading: DecorMark(kind: kind, size: IconSizes.hero),
              title: Text(kind.label),
              subtitle: Text(
                kind.blurb,
                style: text.bodySmall?.copyWith(color: colors.textSecondary),
              ),
              onTap: () => Navigator.of(context).pop(kind),
            ),
        ],
      ),
    );
  }
}

/// A species with plants on the shelf, as one choice in the picker's strip.
///
/// One species looks the same whichever plant it is, so choosing it takes the
/// newest; the shelf tab is where a particular one is picked.
class _ShelvedChoice extends StatelessWidget {
  const _ShelvedChoice(this.spot);

  final ShelfSpot spot;

  static const double _width = 96;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = GardenColors.of(context);
    final count = spot.stored.length;
    void choose() => Navigator.of(context).pop(spot.stored.first);

    return Semantics(
      key: DecorKeys.shelved(spot.species),
      container: true,
      button: true,
      label: '${spot.species.label}, $count on your shelf',
      // excludeSemantics drops the ink well's tap, so it goes here too.
      onTap: choose,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: Radii.smAll,
        onTap: choose,
        child: SizedBox(
          width: _width,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xs),
            child: Column(
              children: [
                PlantMark(plant: spot.stored.first, size: IconSizes.hero),
                const SizedBox(height: Spacing.xs),
                Text(
                  spot.species.label,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
                Text(
                  '$count stored',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A decor sprite drawn small, through the same registry the atlas uses, so the
/// picker shows exactly what ends up in the plot. Not taken from the atlas;
/// it's only four pictures.
class DecorMark extends ConsumerWidget {
  const DecorMark({
    required this.kind,
    this.size = IconSizes.inline,
    super.key,
  });

  final DecorKind kind;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DecorMarkPainter(
          sprite: ref.watch(decorSpriteRegistryProvider).spriteFor(kind),
          palette: DecorPalette(
            material: colors.decor,
            water: colors.skyDay,
            shade: colors.soil,
            glow: colors.bloom,
          ),
        ),
        // Decorative; always shown next to its name.
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DecorMarkPainter extends CustomPainter {
  const _DecorMarkPainter({required this.sprite, required this.palette});

  final DecorSprite sprite;
  final DecorPalette palette;

  @override
  void paint(Canvas canvas, Size size) =>
      sprite.paint(canvas, Offset.zero & size, palette);

  @override
  bool shouldRepaint(_DecorMarkPainter old) =>
      old.sprite != sprite || old.palette != palette;
}

/// A plant drawn small, through the same registry the garden uses. For the
/// arrange bar, next to the name of the plant in hand.
class PlantMark extends ConsumerWidget {
  const PlantMark({
    required this.plant,
    this.size = IconSizes.inline,
    super.key,
  });

  final Plant plant;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: PlantPainter(
          sprite: ref.watch(plantSpriteRegistryProvider).spriteFor(
                form: plant.species.form,
                stage: plant.stage,
              ),
          palette: plantPaletteFor(context, plant.species),
        ),
        // Decorative; always shown next to its name.
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Bottom bar while arranging. Always says what a tap will do, shows what's in
/// hand, and offers a way out.
class ArrangeBar extends ConsumerWidget {
  const ArrangeBar({super.key});

  /// Most of the garden's height the bar may take; the rest stays tappable.
  static const double maxShare = 0.4;

  /// Nothing else explains arranging, so this is also how people find out
  /// plants can be moved.
  static const String choosingGuidance =
      'Tap a plant or object to pick it up. Tap an empty plot to place '
      'something there.';

  /// [name] is what's in hand, as it reads mid-sentence ("bench", "oak").
  static String holdingGuidance(String name) =>
      'Moving the $name. Tap a plot to move it there, or tap something else '
      'to swap.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arranging = ref.watch(gardenArrangerProvider);
    if (arranging is NotArranging) return const SizedBox.shrink();

    final arranger = ref.read(gardenArrangerProvider.notifier);
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);

    final (Widget? mark, String guidance) = switch (arranging) {
      HoldingPlant(:final plant) => (
          PlantMark(plant: plant),
          holdingGuidance(plant.species.label.toLowerCase()),
        ),
      HoldingDecor(:final decor) => (
          DecorMark(kind: decor.kind),
          holdingGuidance(decor.kind.label.toLowerCase()),
        ),
      _ => (null, choosingGuidance),
    };

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        // Capped at [maxShare], or at the largest text sizes the guidance
        // covers every plot. The guidance scrolls; the buttons don't.
        child: LayoutBuilder(
          builder: (context, constraints) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: constraints.maxHeight.isFinite
                  ? constraints.maxHeight * maxShare
                  : double.infinity,
            ),
            child: Material(
              color: theme.colorScheme.surface.withValues(alpha: 0.94),
              borderRadius: Radii.mdAll,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (mark != null) ...[
                              mark,
                              const SizedBox(width: Spacing.sm),
                            ],
                            Flexible(
                              child: Text(
                                key: DecorKeys.guidance,
                                guidance,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: colors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    _buttons(arranging, arranger),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Wraps so that at large text the second button drops under the first
  /// instead of overflowing the bar.
  Widget _buttons(Arranging arranging, GardenArranger arranger) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        if (arranging is Holding) ...[
          // Decor can be removed for good. Plants only go to the shelf.
          if (arranging case HoldingDecor(:final decor))
            TextButton(
              key: DecorKeys.remove,
              onPressed: () => arranger.remove(decor),
              child: const Text('Remove'),
            ),
          if (arranging case final HoldingPlant held)
            TextButton(
              key: DecorKeys.shelve,
              onPressed: () => arranger.shelve(held),
              child: const Text('Move to shelf'),
            ),
          TextButton(
            key: DecorKeys.putDown,
            onPressed: arranger.putDown,
            child: const Text('Leave it'),
          ),
        ] else
          TextButton(
            key: DecorKeys.done,
            onPressed: arranger.end,
            child: const Text('Done'),
          ),
      ],
    );
  }
}
