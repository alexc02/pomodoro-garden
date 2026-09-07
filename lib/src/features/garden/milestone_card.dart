import 'package:flutter/material.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import 'plant_card.dart';

/// Shows the bonus plant card in a bottom sheet, like [showPlantCard]. It
/// arrives unasked, so it leads with what happened and has an obvious close.
/// `MilestoneKeeper` decides when (not while a timer is counting).
Future<void> showMilestoneCard(BuildContext context, Plant plant) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    showDragHandle: true,
    // Sized to content, same as [showPlantCard].
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => MilestoneCard(plant: plant),
  );
}

/// Plant first, count second. No share button, no streak.
class MilestoneCard extends StatelessWidget {
  const MilestoneCard({required this.plant, super.key});

  final Plant plant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);
    // Only built for awarded plants, but the type allows null; show nothing
    // rather than a blank reason.
    final milestone = plant.milestone;
    if (milestone == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
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
            Text(
              '${milestone.label} of focus',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: Spacing.md),
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
            const SizedBox(height: Spacing.sm),
            Text(
              'A bonus plant for your garden. It\'s already planted.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: Spacing.lg),
            // Just a close; the plant is already planted.
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Lovely'),
            ),
          ],
        ),
      ),
    );
  }
}
