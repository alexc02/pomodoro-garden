import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';
import '../../garden/decor_providers.dart';
import '../../garden/decor_sprite.dart';

/// The arranging controls, by name — what a test reaches for rather than "the
/// third button".
abstract final class DecorKeys {
  /// The way into arranging, on the garden's own bar.
  static const Key arrange = Key('decor.arrange');

  /// The way out of it.
  static const Key done = Key('decor.done');

  /// What the bar says the user is doing, and the whole of the mode's guidance.
  static const Key guidance = Key('decor.guidance');

  /// Takes the object in hand out of the garden.
  static const Key remove = Key('decor.remove');

  /// Puts down whatever is in hand, without leaving arranging.
  static const Key putDown = Key('decor.putDown');

  /// One row of the picker, per kind.
  static Key kind(DecorKind kind) => Key('decor.kind.${kind.name}');
}

/// Opens the picker for [plot] and stands whatever the user chooses in it.
///
/// **The plot is chosen first and the object second**, which is the opposite of
/// how a palette usually works and is the right way round here: the garden is a
/// surface the user is composing on, and a picker that armed an object would
/// leave every subsequent tap on the garden ambiguous. Tapping the soil says
/// *something goes here*, and this sheet asks what.
///
/// Returns when the sheet closes. A user who dismisses it has placed nothing —
/// the write happens on a choice, not on the sheet opening.
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

/// REQ-040's four objects, offered.
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
              // The real picture, at the size of an icon: what the user is
              // choosing between is four *objects*, and four words with a
              // generic icon beside them would be a menu rather than a picker.
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

/// One decor object, drawn small: in the picker and in the arranging bar.
///
/// **Drawn through the registry, exactly as the garden's own are.** It is the
/// same sprite the atlas bakes into the texture, asked to paint itself into a
/// box this size instead — so the object the user chooses from the picker is
/// the object that turns up in their plot, and ticket 23 changes both at once
/// by changing neither.
///
/// Not baked into the atlas and not blitted out of it, which would be the wrong
/// trade here: an atlas is what makes two hundred quads one draw call, and this
/// is four pictures on a sheet.
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
        // Decorative: every place this is used names the object in words
        // beside it, so a screen reader has nothing to gain here and would only
        // have to walk past it.
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

/// The bar along the bottom of the garden while the user is arranging it.
///
/// **It says what a tap will do, in the state the user is actually in.** That is
/// the whole of the mode's discoverability: a garden that silently changed what
/// a tap meant would be a garden the user stopped trusting, so the mode
/// announces itself, names what is in hand, and offers the way out at all
/// times.
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
                            ? 'Tap an empty plot to place something, or tap '
                                'something to pick it up.'
                            : 'Moving the ${holding.kind.label.toLowerCase()} '
                                '— tap an empty plot to put it down.',
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
