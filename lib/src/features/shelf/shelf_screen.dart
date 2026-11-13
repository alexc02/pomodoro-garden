import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/headline.dart';
import '../../design/page_header.dart';
import '../../design/paper_card.dart';
import '../../design/sky_band_backdrop.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../garden/plant_painter.dart';
import '../../garden/plant_palettes.dart';
import '../../garden/plant_providers.dart';
import '../../garden/plant_sprite.dart';
import '../../garden/shelf_providers.dart';
import '../../shell/tab.dart';
import '../../shell/tab_glyph.dart';
import '../garden/garden_header.dart';
import 'species_sheet.dart';

abstract final class ShelfKeys {
  static Key row(PlantType type) => Key('shelf.row.${type.name}');
  static Key spot(PlantSpecies species) => Key('shelf.spot.${species.name}');
  static const Key sheet = Key('shelf.sheet');
}

/// The shelf tab: a paper card per plant type, a spot per species.
///
/// All figures come from `shelfProvider` as one [Shelf]; this file only picks
/// words and colours. A spot counts every plant of its species ever grown and
/// shows how many of them are stored here rather than planted.
class ShelfScreen extends ConsumerWidget {
  const ShelfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelf = ref.watch(shelfProvider);

    return Scaffold(
      body: Stack(
        children: [
          const SkyBandBackdrop(depth: 0.24),
          SafeArea(
            bottom: false,
            child: shelf.when(
              // Keep the page up while the plants reload (a finished session,
              // a move): the loading branch would drop the scroll position.
              skipLoadingOnReload: true,
              // Blank rather than a spinner, like the journal.
              loading: () => const SizedBox.expand(),
              error: (error, stack) => const _ShelfUnreadable(),
              data: (shelf) => _ShelfPage(shelf: shelf),
            ),
          ),
        ],
      ),
    );
  }

  /// "Nine of fifty-two found."
  static String headline(Shelf shelf) {
    final all = GardenHeader.inWords(shelf.species);
    if (shelf.discovered == 0) return 'Nothing found yet.';
    if (shelf.discovered == shelf.species) return 'All $all found.';
    final found = GardenHeader.inWords(shelf.discovered);
    return '${found[0].toUpperCase()}${found.substring(1)} of $all found.';
  }

  /// How many plants are stored, or null when the shelf holds none.
  static String? storedLine(Shelf shelf) => switch (shelf.stored) {
        0 => null,
        1 => '1 plant on your shelf',
        final stored => '$stored plants on your shelf',
      };

  static String rowHeading(PlantType type) => switch (type) {
        PlantType.wildflower => 'Wildflowers',
        PlantType.herb => 'Herbs',
        PlantType.flower => 'Flowers',
        PlantType.bush => 'Bushes',
        PlantType.smallTree => 'Small trees',
        PlantType.largeTree => 'Large trees',
        PlantType.bonus => 'Milestone plants',
      };

  /// "Spring only" or "Rare" for species that are harder to come by, null
  /// for the rest. Doesn't give the name away, so it's shown before the
  /// species is found too.
  static String? scarcity(PlantSpecies species) {
    if (species.season case final season?) return '${season.label} only';
    return species.isRare ? 'Rare' : null;
  }

  /// The session lengths that grow the row, worked out from [PlantType] so
  /// the text can't go out of date.
  static String rowRoute(PlantType type) {
    final shortest = type.shortestSession;
    if (shortest == null) return 'Awarded for sessions completed';

    final grown = PlantType.grownBySessions;
    final next = grown.indexOf(type) + 1;
    if (next >= grown.length) {
      return '${shortest.inMinutes} minute sessions and longer';
    }
    final longest = grown[next].shortestSession!.inMinutes - 1;
    return '${shortest.inMinutes} to $longest minute sessions';
  }
}

class _ShelfPage extends StatelessWidget {
  const _ShelfPage({required this.shelf});

  final Shelf shelf;

  @override
  Widget build(BuildContext context) {
    // Not a lazy list: that drops the lower rows from the semantics tree,
    // and seven cards aren't worth recycling.
    return SingleChildScrollView(
      padding: PageHeader.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            eyebrow: ShelfScreen.storedLine(shelf),
            headline: ShelfScreen.headline(shelf),
          ),
          for (final (index, row) in shelf.rows.indexed) ...[
            if (index > 0) const SizedBox(height: Spacing.lg),
            _RowCard(row: row),
          ],
        ],
      ),
    );
  }
}

/// One plant type: heading, the sessions that grow it, then its spots.
class _RowCard extends StatelessWidget {
  const _RowCard({required this.row});

  final ShelfRow row;

  /// Narrowest a spot gets before the row drops to fewer columns.
  static const double _narrowestSpot = 92;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);

    return PaperCard(
      surfaceKey: ShelfKeys.row(row.type),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.md,
          Spacing.lg,
          Spacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // At large text the count wraps under the heading rather than
            // squeezing it. Full width so the count sits at the right edge.
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Spacing.md,
                children: [
                  Semantics(
                    header: true,
                    child: Headline(
                      ShelfScreen.rowHeading(row.type),
                      style: GardenTypography.journalHeading.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${row.discovered} of ${row.spots.length}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Text(
              ShelfScreen.rowRoute(row.type),
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: Spacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                // Three across on a phone. Fewer as the text grows, down to
                // one, so names don't break mid-word.
                final scale = math.max(1.0, systemTextScale(context));
                final narrowest = _narrowestSpot * scale;
                final columns = (constraints.maxWidth / narrowest)
                    .floor()
                    .clamp(1, 6);
                final gaps = Spacing.sm * (columns - 1);
                final width = (constraints.maxWidth - gaps) / columns;

                return Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.md,
                  children: [
                    for (final spot in row.spots)
                      SizedBox(
                        width: width,
                        child: _Spot(spot: spot),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One species: the plant on its plank, then its name, count and marks.
///
/// Not yet grown, it's a soil-coloured outline with no name. Grown but all
/// out in the garden, it's faded. With some stored, it's drawn in full with
/// a count.
class _Spot extends StatelessWidget {
  const _Spot({required this.spot});

  final ShelfSpot spot;

  static const double _plantSide = 64;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);

    final content = Column(
      children: [
        _OnThePlank(spot: spot, side: _plantSide),
        const SizedBox(height: Spacing.sm),
        if (spot.isDiscovered) ...[
          Text(
            spot.species.label,
            textAlign: TextAlign.center,
            style: GardenTypography.botanicalLabel.copyWith(
              color: colors.textPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            spot.milestone == null ? '${spot.grown} grown' : 'Awarded',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
          if (spot.milestone == null) ...[
            const SizedBox(height: Spacing.xs),
            MasteryPips(earned: spot.marks.length),
          ],
        ] else
          Text(
            switch (spot.milestone) {
              final milestone? => 'At ${milestone.label}',
              null => 'Not yet grown',
            },
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
        if (ShelfScreen.scarcity(spot.species) case final scarcity?) ...[
          const SizedBox(height: Spacing.xs),
          Text(
            scarcity,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      key: ShelfKeys.spot(spot.species),
      container: true,
      label: spotSummary(spot),
      button: spot.isDiscovered,
      // excludeSemantics drops the ink well's tap, so it goes here too.
      onTap: spot.isDiscovered
          ? () => showSpeciesSheet(context, spot.species)
          : null,
      excludeSemantics: true,
      child: spot.isDiscovered
          ? InkWell(
              borderRadius: Radii.smAll,
              onTap: () => showSpeciesSheet(context, spot.species),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: content,
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: content,
            ),
    );
  }
}

/// What a screen reader says for [spot]. Names nothing that isn't found yet.
String spotSummary(ShelfSpot spot) {
  final milestone = spot.milestone;
  final scarcity = switch (ShelfScreen.scarcity(spot.species)) {
    final scarcity? => ', ${scarcity.toLowerCase()}',
    null => '',
  };

  if (!spot.isDiscovered) {
    return milestone == null
        ? 'Not yet grown$scarcity'
        : 'Not yet awarded. At ${milestone.label}';
  }

  final stored = switch (spot.stored.length) {
    0 => 'none on your shelf',
    final count => '$count on your shelf',
  };
  if (milestone != null) return '${spot.species.label}, awarded, $stored';

  final marks = '${spot.marks.length} of ${MasteryMark.values.length} marks';
  return '${spot.species.label}$scarcity, ${spot.grown} grown, $marks, $stored';
}

/// The plant standing on its plank, with a count when more than one is stored.
class _OnThePlank extends ConsumerWidget {
  const _OnThePlank({required this.spot, required this.side});

  final ShelfSpot spot;

  final double side;

  /// A plant that's grown but entirely out in the garden.
  static const double _awayOpacity = 0.5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);

    final sprite = ref
        .watch(plantSpriteRegistryProvider)
        .spriteFor(form: spot.species.form, stage: GrowthStage.mature);
    final plant = CustomPaint(
      size: Size.square(side),
      painter: PlantPainter(
        sprite: sprite,
        palette: spot.isDiscovered
            ? plantPaletteFor(context, spot.species)
            : _outline(colors),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: spot.isDiscovered && spot.stored.isEmpty ? _awayOpacity : 1,
          child: plant,
        ),
        if (spot.stored.length > 1)
          Positioned(
            top: 0,
            right: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: Radii.pillAll,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: 2,
                ),
                child: Text(
                  '×${spot.stored.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: GardenTypography.headingWeight,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Every role in one muted colour, so only the shape shows.
  static PlantPalette _outline(GardenColors colors) {
    final shade = colors.soil.withValues(alpha: 0.45);
    return PlantPalette(foliage: shade, bloom: shade, soil: colors.soil);
  }
}

/// The four mastery marks as dots: filled once earned.
class MasteryPips extends StatelessWidget {
  const MasteryPips({required this.earned, super.key});

  final int earned;

  static const double _side = 7;

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);

    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var mark = 0; mark < MasteryMark.values.length; mark++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mark < earned ? colors.foliage : null,
                  border: Border.all(
                    color: mark < earned
                        ? colors.foliage
                        : colors.textSecondary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: const SizedBox.square(dimension: _side),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown when the shelf can't be read. Same promise as the garden's.
class _ShelfUnreadable extends StatelessWidget {
  const _ShelfUnreadable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Spacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabGlyph(
              AppTab.shelf,
              size: IconSizes.hero,
              color: GardenColors.of(context).textSecondary,
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'Your shelf couldn\'t be opened just now. Nothing\'s lost. Try '
              'again in a moment.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
