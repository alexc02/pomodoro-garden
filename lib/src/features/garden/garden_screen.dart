import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';
import '../../garden/decor_providers.dart';
import '../../garden/garden_providers.dart';
import '../../garden/garden_transition.dart';
import '../../garden/season_weather.dart';
import '../../shell/tab.dart';
import '../../shell/tab_glyph.dart';
import 'decor_picker.dart';
import 'export_garden.dart';
import 'garden_backdrop.dart';
import 'garden_header.dart';
import 'garden_timer_bar.dart';
import 'garden_view.dart';
import 'seasonal_garden.dart';

/// The garden tab: [GardenHeader] over [GardenView] on [GardenBackdrop]'s
/// hills, plus a caption when there's something to say. No app bar.
///
/// [SeasonalGarden] applies season and theme to this subtree only.
class GardenScreen extends ConsumerWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garden = ref.watch(gardenLayoutProvider);

    return SeasonalGarden(
      builder: (context, skin) => Scaffold(
        // The skin's sky, shown for the frame before [GardenBackdrop] paints
        // and behind the garden when zoomed out.
        backgroundColor: GardenColors.of(context).skyDay,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Outside SafeArea so the sky runs up under the status bar.
            const GardenBackdrop(),
            SafeArea(
              child: garden.when(
                // Blank sky rather than a spinner; the query is small and the
                // garden fades in anyway.
                loading: () => const SizedBox.expand(),
                error: (error, stack) => const _GardenUnreadable(),
                // Header overlays the garden instead of sitting in a column,
                // which would push the garden off small phones at large text.
                data: (layout) => Stack(
                  fit: StackFit.expand,
                  children: [
                    _GardenStage(layout: layout, skin: skin),
                    Align(
                      alignment: Alignment.topCenter,
                      child: GardenHeader(
                        plants: layout.plants.length,
                        actions: const [ExportGardenAction(), _Arrange()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Minimum garden height to fit a caption above the timer bar at its
  /// tallest (narrow screens wrap the bar's button).
  static const double _roomForCaption = 300;

  /// Bonus plants are listed separately so the total doesn't overstate the
  /// sessions behind it.
  static String _summary(GardenLayout garden) {
    final plants = garden.plants.length;
    final grown = plants == 1 ? '1 plant' : '$plants plants';
    final plots =
        garden.plotCount == 1 ? '1 plot' : '${garden.plotCount} plots';
    final awarded = garden.bonusPlants.length;
    final bonus = awarded == 1 ? '1 bonus plant' : '$awarded bonus plants';

    final growing = switch ((plants, awarded)) {
      (0, _) => 'Your garden: $plots of bare soil, nothing growing yet.',
      (_, 0) => 'Your garden: $grown in $plots.',
      _ => 'Your garden: $grown in $plots, $bonus among them.',
    };

    // The garden is painted, so screen readers get this summary instead.
    // Counted, not listed; there can be fifty pieces.
    final placed = garden.decor.length;
    if (placed == 0) return growing;

    return placed == 1
        ? '$growing One thing you placed stands among them.'
        : '$growing $placed things you placed stand among them.';
  }

  /// Shown once the garden is full. The extra plants are kept, just not placed.
  static String _holdingMessage(int waiting) => waiting == 1
      ? 'Your garden is full. One more plant is waiting for space.'
      : 'Your garden is full. $waiting more plants are waiting for space.';
}

/// The garden, its weather, then the caption and timer bar along the bottom.
class _GardenStage extends StatelessWidget {
  const _GardenStage({required this.layout, required this.skin});

  final GardenLayout layout;

  final GardenTransition skin;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          // Semantics on the painting only, so the caption stays its own node.
          label: GardenScreen._summary(layout),
          child: GardenView(layout: layout),
        ),
        // Weather in front of plants but behind any text.
        SeasonWeather(transition: skin),
        // Caption over the timer bar. If there's only room for one, the bar
        // wins.
        LayoutBuilder(
          builder: (context, constraints) {
            final roomy =
                constraints.maxHeight >= GardenScreen._roomForCaption;
            return Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!roomy)
                    const SizedBox.shrink()
                  else if (layout.plants.isEmpty)
                    const _Caption('Finish a session and your first plant goes '
                        'in here.')
                  else if (layout.unplaced.isNotEmpty)
                    _Caption(GardenScreen._holdingMessage(
                      layout.unplaced.length,
                    )),
                  const GardenTimerBar(),
                ],
              ),
            );
          },
        ),
        // Arrange bar on top; it's empty when not arranging.
        const ArrangeBar(),
      ],
    );
  }
}

/// Toggles arranging mode on and off.
class _Arrange extends ConsumerWidget {
  const _Arrange();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arranging = ref.watch(decorArrangerProvider) is! NotArranging;
    final arranger = ref.read(decorArrangerProvider.notifier);

    return IconButton(
      key: DecorKeys.arrange,
      icon: Icon(arranging ? Icons.close : Icons.chair_outlined),
      tooltip: arranging ? 'Stop arranging' : 'Arrange your garden',
      onPressed: arranging ? arranger.end : arranger.begin,
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.lg,
        Spacing.lg,
        Spacing.xs,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.82),
          borderRadius: Radii.pillAll,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: GardenColors.of(context).textSecondary),
          ),
        ),
      ),
    );
  }
}

/// Shown when the garden can't be read. The plants aren't gone; an empty
/// garden would say otherwise.
class _GardenUnreadable extends StatelessWidget {
  const _GardenUnreadable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: Spacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabGlyph(
              AppTab.garden,
              size: IconSizes.hero,
              color: GardenColors.of(context).textSecondary,
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'Your garden couldn\'t be opened just now. Nothing\'s lost. Try '
              'again in a moment.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
