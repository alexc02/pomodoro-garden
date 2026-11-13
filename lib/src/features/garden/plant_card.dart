import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../garden/plant_painter.dart';
import '../../garden/plant_palettes.dart';
import '../../garden/plant_providers.dart';

/// Shows [plant]'s card in a modal bottom sheet, which gives swipe-down, tap
/// outside and back-gesture dismissal for free.
Future<void> showPlantCard(BuildContext context, Plant plant) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    showDragHandle: true,
    // Size to content; at the largest text size the card is half again as
    // tall.
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => PlantCard(plant: plant),
  );
}

/// What a plant is, when it was planted, and a quote.
class PlantCard extends StatelessWidget {
  const PlantCard({required this.plant, super.key});

  final Plant plant;

  static const double portraitSide = 132;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);

    return SafeArea(
      top: false,
      // Only scrolls when it doesn't fit, so the swipe-to-dismiss isn't
      // swallowed by an empty scroll extent.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          0,
          Spacing.lg,
          Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlantPortrait(plant: plant),
            const SizedBox(height: Spacing.md),
            Text(
              plant.species.label,
              textAlign: TextAlign.center,
              // Handwritten face is for plant names only.
              style: GardenTypography.botanicalLabel.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              plant.type.label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: Spacing.lg),
            _Fact(label: 'Planted', value: plantedOn(plant.plantedAt)),
              // Bonus plants show their milestone instead of a session
              // length; a plant never has both.
            if (plant.milestone case final milestone?)
              _Fact(label: 'Awarded at', value: milestone.label)
            else if (plant.sessionDuration case final duration?)
              _Fact(label: 'Session', value: sessionLengthInWords(duration)),
            _Fact(label: 'Growth', value: plant.stage.label),
            const SizedBox(height: Spacing.lg),
            _Quote(PlantQuotes.forPlant(plant.id)),
          ],
        ),
      ),
    );
  }
}

/// The plant drawn at card size, through the sprite registry. Public so the
/// milestone card can reuse it.
class PlantPortrait extends ConsumerWidget {
  const PlantPortrait({required this.plant, super.key});

  final Plant plant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SizedBox.square(
        dimension: PlantCard.portraitSide,
        child: CustomPaint(
          painter: PlantPainter(
            sprite: ref.watch(plantSpriteRegistryProvider).spriteFor(
                  form: plant.species.form,
                  stage: plant.stage,
                ),
            palette: plantPaletteFor(context, plant.species),
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Semantics(
        // One node, so it reads "Planted, 11 August 2026".
        label: '$label: $value',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(width: Spacing.md),
            // Value wraps in the remaining space for long values and large
            // text.
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote(this.quote);

  final String quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: Radii.mdAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Text(
          quote,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

/// Planted date in local time (stored as UTC), e.g. "11 August 2026". See
/// [Plant.plantedAt]. Hand-rolled rather than pulling in `intl` for one format.
String plantedOn(DateTime plantedAt) {
  final local = plantedAt.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Session length in words. Sessions are 5 min to 2 h, so no days or seconds.
String sessionLengthInWords(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;

  final parts = [
    if (hours > 0) '$hours ${hours == 1 ? 'hour' : 'hours'}',
    // "1 hour", not "1 hour 0 minutes". Zero length (shouldn't happen) still
    // says "0 minutes".
    if (minutes > 0 || hours == 0)
      '$minutes ${minutes == 1 ? 'minute' : 'minutes'}',
  ];

  return parts.join(' ');
}
