import 'package:flutter/material.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import 'plant_card.dart';

/// Raises the card that celebrates a bonus plant: REQ-021.
///
/// A sheet, like [showPlantCard], and for the same three dismissals — swipe,
/// scrim, back gesture — but it says something different. The plant card
/// describes a plant the user went looking for; this one arrives unasked, so it
/// leads with what happened and gives the user an obvious way out rather than
/// leaving them to find one.
///
/// *When* it is raised is not decided here. `MilestoneKeeper` holds an award
/// back until nothing is counting down, so nothing in this file has to know
/// what a session is.
Future<void> showMilestoneCard(BuildContext context, Plant plant) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    showDragHandle: true,
    // The reason [showPlantCard] takes its own height: a card is a fixed
    // handful of lines, and at the largest text size the system offers the same
    // card is half again as tall.
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => MilestoneCard(plant: plant),
  );
}

/// What the app says when a milestone is reached.
///
/// Quiet, and about the work rather than about the app: the plant is the
/// headline and the count is the reason it is there. There is no share button
/// and no streak — the reward for a hundred sessions is a tree in a garden the
/// user keeps.
class MilestoneCard extends StatelessWidget {
  const MilestoneCard({required this.plant, super.key});

  final Plant plant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);
    // A card is only ever built for a plant a milestone awarded — `Plant`
    // carries the milestone and `MilestoneKeeper` only queues bonus plants —
    // but the type says it could be null, and a card with a blank line where
    // the reason should be is worse than one that says nothing at all.
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
              // §5.1: plant names, and only plant names, in the handwritten
              // face — the label on the stake in the soil.
              style: GardenTypography.botanicalLabel.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'A bonus plant for your garden. It is already standing in it.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: Spacing.lg),
            // One control, and it does nothing but close: the plant is already
            // planted by the time this is on screen, so there is no decision
            // here for the user to get wrong.
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
