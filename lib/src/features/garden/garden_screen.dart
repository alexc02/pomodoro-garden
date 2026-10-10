import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';
import '../../garden/decor_providers.dart';
import '../../garden/garden_providers.dart';
import '../../garden/season_weather.dart';
import '../../shell/tab.dart';
import '../journal/journal_paper.dart';
import 'decor_picker.dart';
import 'export_garden.dart';
import 'garden_timer_bar.dart';
import 'garden_view.dart';
import 'seasonal_garden.dart';

/// The garden: every plant the user has grown, laid out isometrically, and
/// pannable.
///
/// The product's whole emotional premise lives on this screen — the garden is
/// here tomorrow, next week and next month — so it is deliberately mostly
/// garden. There is no app bar over it and no chrome in it; the only thing this
/// screen adds to [GardenView] is a word when the garden has something to say.
///
/// REQ-019's season and REQ-034's theme are put on here, by [SeasonalGarden],
/// and reach no further than this subtree: the colours arrive through the theme
/// and the weather through one overlay, and the garden underneath both is the
/// same garden it was in July and in the Zen garden.
class GardenScreen extends ConsumerWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garden = ref.watch(gardenLayoutProvider);

    return SeasonalGarden(
      builder: (context, skin) => Scaffold(
        // §5.2's "navigation bar (minimal)", and the same one every other tab
        // has: the garden is the screen, and the bar is there to name it.
        appBar: AppBar(
          title: Text(AppTab.garden.label),
          // REQ-035's export beside REQ-040's arranging: the two things a user
          // does *to* the garden rather than in it.
          actions: const [ExportGardenAction(), _Arrange()],
        ),
        // The sky, and the whole background: the garden is drawn on top of it
        // and is smaller than it whenever the user has zoomed out. It is the
        // skin's sky rather than the app's, which is the largest single thing
        // a change of season or of theme does to the screen.
        backgroundColor: GardenColors.of(context).skyDay,
        body: SafeArea(
          child: garden.when(
            // A blank sky rather than a spinner. The read is one query against
            // a table of at most two hundred rows, and a spinner that appears
            // for a frame and a half is worse than a background that was going
            // to be there anyway — the garden fades in over it either way,
            // §5.3.
            loading: () => const SizedBox.expand(),
            error: (error, stack) => const _GardenUnreadable(),
            data: (layout) => Stack(
              fit: StackFit.expand,
              children: [
                // The sky is paper too (PRD v2.2 §9.1): the journal's fibres,
                // laid once over the sky colour and never repainted as the
                // garden pans over them.
                RepaintBoundary(
                  child: CustomPaint(
                    painter: PaperPainter(
                      fibre: GardenColors.of(context).textSecondary,
                      wash: GardenColors.of(context).soil,
                    ),
                  ),
                ),
                Semantics(
                  // The garden is one painted surface, so it has no widgets for
                  // a screen reader to walk and has to say what it holds
                  // itself. Wrapped around the painting alone rather than
                  // around the whole stack, so that the caption below stays a
                  // line of its own rather than being merged into this one.
                  label: _summary(layout),
                  child: GardenView(layout: layout),
                ),
                // In front of the plants and behind anything the garden has to
                // say: weather falls through a garden, not across a sentence.
                SeasonWeather(transition: skin),
                // Along the bottom, the garden's one line of text, when it has
                // something to say, over US-006's timer bar. On a garden too
                // short for both, the bar wins: starting a session is the thing
                // to do, and the caption only describes the garden.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final roomy = constraints.maxHeight >= _roomForCaption;
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!roomy)
                            const SizedBox.shrink()
                          else if (layout.plants.isEmpty)
                            const _Caption('Finish a session and the first '
                                'thing you grow stands here.')
                          else if (layout.unplaced.isNotEmpty)
                            _Caption(_holdingMessage(layout.unplaced.length)),
                          const GardenTimerBar(),
                        ],
                      ),
                    );
                  },
                ),
                // REQ-040's arranging, over everything: it is the only thing on
                // this screen the user is *doing* rather than looking at, and
                // it is nothing at all when they are not.
                const ArrangeBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// How tall the garden must be to show a caption above the timer bar
  /// without either being pushed off the bottom.
  static const double _roomForCaption = 240;

  /// What the garden amounts to, in a sentence.
  ///
  /// The bonus plants are counted out separately rather than folded into the
  /// total, and that is REQ-021's "recorded as bonus" said out loud: a garden
  /// of forty plants where seven were awarded is not forty afternoons of work,
  /// and a sentence that implied it was would be the app flattering the user
  /// with their own sessions.
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

    // REQ-040's arrangement, said out loud rather than left as pixels. The
    // garden is one painted surface, so a reader that cannot see it is told
    // what is in it by this sentence and by nothing else — and a feature whose
    // whole point is that the user composed something would be invisible to
    // them otherwise. Counted rather than named: a garden can hold fifty of
    // these, and a list of fifty is not a sentence.
    final placed = garden.decor.length;
    if (placed == 0) return growing;

    return placed == 1
        ? '$growing One thing you placed stands among them.'
        : '$growing $placed things you placed stand among them.';
  }

  /// What a full garden says about the plants it has no room for.
  ///
  /// Said out loud rather than swallowed, which is the visible half of ADR
  /// 0006: the plants are kept, they are simply not standing anywhere. Reaching
  /// this takes two hundred completed sessions.
  static String _holdingMessage(int waiting) => waiting == 1
      ? 'Your garden is full. One more plant is waiting for space.'
      : 'Your garden is full. $waiting more plants are waiting for space.';
}

/// The way into REQ-040's arranging, and the way back out of it.
///
/// A toggle rather than a one-way door because the garden is the surface being
/// arranged: there is no separate arranging screen to leave, only a mode this
/// turns off.
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

/// A line of quiet text along the bottom of the garden.
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

/// What the tab shows when the garden cannot be read off the disk.
///
/// The same reasoning the settings and the restored session use: a launch that
/// cannot read one thing should still open. The user's plants are not gone —
/// this build could not load them — and saying so is better than an empty
/// garden, which would say something untrue.
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
            Icon(
              AppTab.garden.icon,
              size: IconSizes.hero,
              color: GardenColors.of(context).textSecondary,
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'Your garden could not be opened just now. Nothing has been '
              'lost — try again in a moment.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
