import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';
import '../../garden/decor_providers.dart';
import '../../garden/decor_sprite.dart';

abstract final class DecorKeys {
  /// Enters arranging mode, on the garden's bar.
  static const Key arrange = Key('decor.arrange');

  static const Key done = Key('decor.done');

  /// The bar's hint text.
  static const Key guidance = Key('decor.guidance');

  /// Removes the held object from the garden.
  static const Key remove = Key('decor.remove');

  /// Drops the held object without leaving arranging.
  static const Key putDown = Key('decor.putDown');

  static Key kind(DecorKind kind) => Key('decor.kind.${kind.name}');
}

/// Opens the picker for [plot] and places whatever is chosen. Plot first,
/// object second, so taps on the garden are never ambiguous. Dismissing places
/// nothing.
Future<void> showDecorPicker(
  BuildContext context,
  WidgetRef ref,
  GardenPlot plot,
) async {
  final kind = await showModalBottomSheet<DecorKind>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _DecorPicker(),
  );

  if (kind == null || !context.mounted) return;
  await ref.read(decorArrangerProvider.notifier).place(kind, plot);
}

class _DecorPicker extends ConsumerWidget {
  const _DecorPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final colors = GardenColors.of(context);

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, Spacing.lg),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Text('Place something here', style: text.titleLarge),
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

/// Bottom bar while arranging. Always says what a tap will do, shows what's in
/// hand, and offers a way out.
class ArrangeBar extends ConsumerWidget {
  const ArrangeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arranging = ref.watch(decorArrangerProvider);
    if (arranging is NotArranging) return const SizedBox.shrink();

    final arranger = ref.read(decorArrangerProvider.notifier);
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);
    final holding = arranging is Holding ? arranging.decor : null;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Material(
          color: theme.colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: Radii.mdAll,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (holding != null) ...[
                      DecorMark(kind: holding.kind),
                      const SizedBox(width: Spacing.sm),
                    ],
                    Flexible(
                      child: Text(
                        key: DecorKeys.guidance,
                        holding == null
                            ? 'Tap an empty plot to place something. Tap '
                                'something to pick it up.'
                            : 'Moving the ${holding.kind.label.toLowerCase()}. '
                                'Tap an empty plot to put it down.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (holding != null) ...[
                      TextButton(
                        key: DecorKeys.remove,
                        onPressed: () => arranger.remove(holding),
                        child: const Text('Remove'),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
