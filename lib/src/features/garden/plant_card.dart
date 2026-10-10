import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../garden/plant_painter.dart';
import '../../garden/plant_palettes.dart';
import '../../garden/plant_providers.dart';

/// Raises [plant]'s card over the garden: REQ-020.
///
/// A modal sheet rather than a dialog, for the three dismissals ticket 12 asks
/// for. A sheet is swiped down, tapped away through the scrim and popped by the
/// platform's back gesture, and all three come from the route rather than from
/// anything written here — which is the point. A hand-rolled overlay would have
/// to reimplement each of them, and would get the back gesture wrong, because
/// the back gesture is a route being popped and nothing else.
Future<void> showPlantCard(BuildContext context, Plant plant) {
  return showModalBottomSheet<void>(
    context: context,
    // §5.3's vocabulary: things in this app arrive gently. The sheet keeps the
    // garden visible behind it, because the card is about a plant the user can
    // still see.
    backgroundColor: Theme.of(context).colorScheme.surface,
    showDragHandle: true,
    // The sheet takes the height its card needs rather than the nine-sixteenths
    // a bottom sheet defaults to. A card is a fixed handful of lines, but how
    // tall those lines are is the user's business: at the largest text size the
    // system offers, the same card is half again as tall.
    isScrollControlled: true,
    // …and stays out from under the notch when it does grow that tall.
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => PlantCard(plant: plant),
  );
}

/// What one plant is, when it was grown, and a line about growth: REQ-020.
///
/// The whole of the ticket's product argument in one screenful — every plant
/// here came from an afternoon somebody spent, and this is where the app says
/// which afternoon.
class PlantCard extends StatelessWidget {
  const PlantCard({required this.plant, super.key});

  final Plant plant;

  /// How big the plant is drawn at the top of the card.
  static const double portraitSide = 132;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);

    return SafeArea(
      top: false,
      // Scrollable only when it has to be: a card that fits has no scroll
      // extent, so the swipe that dismisses it is not swallowed by a list that
      // has nowhere to go. A card that does not fit — a small phone at the
      // largest text size — scrolls rather than clipping the quote off.
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
              // §5.1: plant names, and only plant names, are set in the
              // handwritten face. This is the label on the stake in the soil.
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
            _Fact(label: 'Planted', value: _plantedOn(plant.plantedAt)),
            // REQ-021: a bonus plant says what earned it where every other
            // plant says how long it took. The two never both apply — a plant
            // has a session or a milestone — so this is one row either way
            // rather than a card that grows a line for the awards.
            if (plant.milestone case final milestone?)
              _Fact(label: 'Awarded at', value: milestone.label)
            else if (plant.sessionDuration case final duration?)
              _Fact(label: 'Session', value: _sessionLength(duration)),
            _Fact(label: 'Growth', value: plant.stage.label),
            const SizedBox(height: Spacing.lg),
            _Quote(PlantQuotes.forPlant(plant.id)),
          ],
        ),
      ),
    );
  }
}

/// The plant itself, at the top of a card.
///
/// Drawn through the registry like every other plant on screen — a card is not
/// allowed to know what a sunflower looks like any more than the garden is.
///
/// Public because ticket 13's milestone card shows the plant it is celebrating
/// the same way this one shows the plant it is describing, and two copies of
/// "draw a plant at card size" would be two things to change when ticket 23
/// swaps the art.
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
                  type: plant.type,
                  stage: plant.stage,
                ),
            palette: plantPaletteFor(context, plant.species),
          ),
        ),
      ),
    );
  }
}

/// One labelled thing the card knows about the plant.
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
        // Read as one thing rather than as two, so a screen reader says
        // "Planted, 11 August 2026" instead of leaving the label stranded.
        label: '$label: $value',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(width: Spacing.md),
            // The value takes the rest of the row and wraps inside it. A fixed
            // pair of labels would fit "25 minutes" and run off the edge of a
            // narrow phone at "1 hour 30 minutes" — or at any text size the
            // user chose that this was not laid out against.
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

/// The line about growth or patience.
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

/// The day the seed went in, as a user would say it.
///
/// The plant's date is stored in UTC and read here in the user's own time zone,
/// because "the evening I worked" is a local idea — a session anchored at 23:50
/// belongs to that evening on the phone that ran it, not to the next day in
/// Greenwich. See [Plant.plantedAt].
///
/// Written out rather than taken from `intl`: this is one date in one format,
/// and the package is a megabyte of locale data and a dependency for it.
/// Ticket 15's journal is where a real localised format earns its keep.
String _plantedOn(DateTime plantedAt) {
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

/// How long the session was, in words.
///
/// Words rather than the timer's digits: `1:30:00` is a countdown, and this is
/// a memory of an afternoon. Sessions run from five minutes to two hours
/// (REQ-030), so there is no case here for days or seconds.
String _sessionLength(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;

  final parts = [
    if (hours > 0) '$hours ${hours == 1 ? 'hour' : 'hours'}',
    // A round hour says "1 hour", not "1 hour 0 minutes"; a session of no
    // length at all — which nothing in the app can produce — says "0 minutes"
    // rather than nothing.
    if (minutes > 0 || hours == 0)
      '$minutes ${minutes == 1 ? 'minute' : 'minutes'}',
  ];

  return parts.join(' ');
}
