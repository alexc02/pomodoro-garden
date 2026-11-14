import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/headline.dart';
import '../../design/spacing.dart';
import '../../garden/daylight_providers.dart';
import '../../garden/decor_providers.dart';
import '../../garden/garden_providers.dart';
import '../../garden/garden_transition.dart';
import '../../garden/season_weather.dart';
import '../../session/session_providers.dart';
import '../../shell/shell_providers.dart';
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

  /// The "garden is full" caption, which opens the shelf.
  static const Key fullCaption = Key('garden.fullCaption');

  /// The caption for a garden whose plants are all on the shelf. Opens it too.
  static const Key shelvedCaption = Key('garden.shelvedCaption');

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
                // Otherwise every move or new plant rebuilds [GardenView]
                // from scratch, which resets the camera and logs a visit.
                skipLoadingOnReload: true,
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
                      child: _SkyInk(
                        child: GardenHeader(
                          plants: layout.plants.length,
                          actions: const [ExportGardenAction(), _Arrange()],
                        ),
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

  /// Shown once every plot holds a plant. Anything grown after that goes to
  /// the shelf, and tapping the caption opens it.
  static String _fullMessage(int shelved) => shelved == 1
      ? 'Your garden is full. 1 plant is on your shelf.'
      : 'Your garden is full. $shelved plants are on your shelf.';

  /// Having plants on the shelf doesn't mean the garden is full; the user can
  /// shelve plants with plenty of soil to spare.
  static bool _isFull(GardenLayout garden) =>
      garden.shelved.isNotEmpty && garden.plants.length >= GardenPlots.maximum;
}

/// The garden, its weather, then the caption and timer bar along the bottom.
class _GardenStage extends ConsumerWidget {
  const _GardenStage({required this.layout, required this.skin});

  final GardenLayout layout;

  final GardenTransition skin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            // The room needed grows with the text size. No caption while
            // arranging either, or it shows through under the arrange bar.
            final textScale = math.max(1.0, systemTextScale(context));
            final roomy = constraints.maxHeight >=
                    GardenScreen._roomForCaption * textScale &&
                ref.watch(gardenArrangerProvider) is NotArranging;
            void openShelf() =>
                ref.read(selectedTabProvider.notifier).select(AppTab.shelf);

            return Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!roomy)
                    const SizedBox.shrink()
                  else if (layout.plants.isEmpty && layout.shelved.isEmpty)
                    const _Caption('Finish a session and your first plant goes '
                        'in here.')
                  // Everything grown so far was put away.
                  else if (layout.plants.isEmpty)
                    _Caption(
                      'Every plant you\'ve grown is on your shelf.',
                      key: GardenScreen.shelvedCaption,
                      onTap: openShelf,
                    )
                  else if (GardenScreen._isFull(layout))
                    _Caption(
                      GardenScreen._fullMessage(layout.shelved.length),
                      key: GardenScreen.fullCaption,
                      onTap: openShelf,
                    ),
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

/// Picks the header's text and icon colour from the sky behind it, since the
/// sky no longer matches light/dark mode.
class _SkyInk extends ConsumerWidget {
  const _SkyInk({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final ink = GardenSky(
      day: colors.skyDay,
      daylight: ref.watch(daylightProvider),
    ).ink;

    return Theme(
      data: Theme.of(context).copyWith(
        extensions: [colors.copyWith(textPrimary: ink)],
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: ink),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(color: ink),
      ),
      child: child,
    );
  }
}

/// Toggles arranging mode on and off.
class _Arrange extends ConsumerWidget {
  const _Arrange();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arranging = ref.watch(gardenArrangerProvider) is! NotArranging;
    final arranger = ref.read(gardenArrangerProvider.notifier);
    final held = ref.watch(
      sessionControllerProvider
          .select((session) => sessionHoldsTheGarden(session.phase)),
    );

    if (arranging) {
      return IconButton(
        key: DecorKeys.arrange,
        icon: const Icon(Icons.close),
        tooltip: 'Stop arranging',
        onPressed: arranger.end,
      );
    }
    return IconButton(
      key: DecorKeys.arrange,
      icon: const Icon(Icons.chair_outlined),
      tooltip: held
          ? 'Arrange your garden once your session ends'
          : 'Arrange your garden',
      onPressed: held ? null : arranger.begin,
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.message, {this.onTap, super.key});

  final String message;

  /// Makes the caption a button. Null for one that only says something.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Has to be a direct child of the stage's column. At large text on a
    // small phone the caption and the timer bar don't both fit, and this way
    // the caption scrolls instead of the column overflowing.
    return Flexible(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.lg,
          Spacing.lg,
          Spacing.xs,
        ),
        child: Material(
          color: theme.colorScheme.surface.withValues(alpha: 0.82),
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
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
