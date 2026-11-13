import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../garden/decor_providers.dart';
import '../../garden/garden_providers.dart';
import '../../garden/plant_painter.dart';
import '../../garden/plant_palettes.dart';
import '../../garden/plant_providers.dart';
import '../../garden/shelf_providers.dart';
import '../../session/session_providers.dart';
import '../garden/plant_card.dart';
import 'shelf_screen.dart';

/// Shows a found species' sheet: what it is, how far its marks have got, and
/// each plant of it stored on the shelf, with a way back to the garden. Same
/// sheet as [showPlantCard].
Future<void> showSpeciesSheet(BuildContext context, PlantSpecies species) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => SpeciesSheet(species: species),
  );
}

/// Why a stored plant can't go back to the garden right now.
enum _Held {
  /// A session is counting down; its own plant is about to be placed.
  bySession('You can plant these once your session ends.'),

  /// Every plot holds a plant or an object.
  byFullGarden(
    'Your garden has no free plot. Move a plant to your shelf to make room.',
  );

  const _Held(this.reason);

  final String reason;
}

/// Watches the shelf rather than holding a spot, so the list shortens as
/// plants go back to the garden.
class SpeciesSheet extends ConsumerWidget {
  const SpeciesSheet({required this.species, super.key});

  final PlantSpecies species;

  /// "12 grown · next mark at 25".
  static String progress(ShelfSpot spot) {
    if (spot.milestone case final milestone?) {
      return 'Awarded at ${milestone.label}';
    }
    return switch (spot.nextMark) {
      final next? => '${spot.grown} grown · next mark at ${next.grown}',
      null => '${spot.grown} grown · every mark earned',
    };
  }

  static Key plantOut(Plant plant) => Key('shelf.plantOut.${plant.id}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);

    final spot = ref.watch(shelfProvider).value?.spotFor(species);
    // Only opened from a loaded shelf; a reset behind the sheet empties it.
    if (spot == null) return const SizedBox.shrink();

    final garden = ref.watch(gardenLayoutProvider).value;
    // Same rule as arranging.
    final inSession = ref.watch(
      sessionControllerProvider
          .select((session) => sessionHoldsTheGarden(session.phase)),
    );
    final gardenFull = garden != null &&
        garden.plants.length + garden.decor.length >= GardenPlots.maximum;

    _Held? held;
    if (inSession) {
      held = _Held.bySession;
    } else if (gardenFull) {
      held = _Held.byFullGarden;
    }

    return SafeArea(
      key: ShelfKeys.sheet,
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
            _Portrait(species: species),
            const SizedBox(height: Spacing.md),
            Text(
              species.label,
              textAlign: TextAlign.center,
              style: GardenTypography.botanicalLabel.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              switch (ShelfScreen.scarcity(species)) {
                final scarcity? => '${species.type.label} · $scarcity',
                null => species.type.label,
              },
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: Spacing.md),
            if (spot.milestone == null) ...[
              Center(child: MasteryPips(earned: spot.marks.length)),
              const SizedBox(height: Spacing.sm),
            ],
            Text(
              progress(spot),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Spacing.lg),
            Semantics(
              header: true,
              child: Text('On your shelf', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: Spacing.xs),
            if (spot.stored.isEmpty)
              Text(
                spot.grown == 1
                    ? 'It\'s in your garden.'
                    : 'All ${spot.grown} are in your garden.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colors.textSecondary),
              )
            else ...[
              if (held != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  child: Text(
                    held.reason,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textSecondary),
                  ),
                ),
              for (final plant in spot.stored)
                _StoredPlant(plant, canPlant: held == null),
            ],
          ],
        ),
      ),
    );
  }
}

/// One stored plant: the day it was planted, the session behind it, and the
/// way back to the garden.
class _StoredPlant extends ConsumerWidget {
  const _StoredPlant(this.plant, {required this.canPlant});

  final Plant plant;

  final bool canPlant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final planted = plantedOn(plant.plantedAt);
    final behind = switch ((plant.milestone, plant.sessionDuration)) {
      (final milestone?, _) => milestone.label,
      (_, final duration?) => sessionLengthInWords(duration),
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      // Wraps so the button can drop under the date at large text.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Spacing.sm,
        children: [
          Semantics(
            // One node, so it reads "3 March 2026, 1 hour 30 minutes".
            label: behind == null ? planted : '$planted, $behind',
            excludeSemantics: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(planted, style: theme.textTheme.bodyMedium),
                if (behind != null)
                  Text(behind, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          TextButton(
            key: SpeciesSheet.plantOut(plant),
            onPressed: canPlant
                ? () => ref
                    .read(gardenArrangerProvider.notifier)
                    .plantInGarden(plant)
                : null,
            child: Semantics(
              // There can be several, so say which plant this one is for.
              label: 'Plant in garden, $planted',
              excludeSemantics: true,
              child: const Text('Plant in garden'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Portrait extends ConsumerWidget {
  const _Portrait({required this.species});

  final PlantSpecies species;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SizedBox.square(
        dimension: PlantCard.portraitSide,
        child: CustomPaint(
          painter: PlantPainter(
            sprite: ref.watch(plantSpriteRegistryProvider).spriteFor(
                  form: species.form,
                  stage: GrowthStage.mature,
                ),
            palette: plantPaletteFor(context, species),
          ),
        ),
      ),
    );
  }
}
