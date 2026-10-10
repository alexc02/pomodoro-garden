import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/spacing.dart';
import '../../onboarding/onboarding.dart';
import '../../onboarding/onboarding_providers.dart';
import '../../shell/tab.dart';

/// What the three coach marks point at.
///
/// Global keys rather than coordinates, because a coach mark has to find the
/// thing itself: the ring is as big as the screen lets it be and the tab
/// destinations are laid out by the bar, so anything written down here would be
/// a second opinion about where they are. The widgets that carry these keys are
/// the real ones — this is the whole of what "over the live UI" costs the
/// screens involved.
abstract final class CoachMarkTargets {
  /// The session ring on the timer screen: the countdown, and the plant.
  static final GlobalKey timer = GlobalKey(debugLabel: 'coachMark.timer');

  /// The garden tab's destination in the bar.
  static final GlobalKey garden = GlobalKey(debugLabel: 'coachMark.garden');

  /// The journal tab's destination in the bar.
  static final GlobalKey journal = GlobalKey(debugLabel: 'coachMark.journal');

  /// The key [tab]'s destination carries, or null for a tab no coach mark
  /// points at.
  static GlobalKey? forTab(AppTab tab) => switch (tab) {
        AppTab.garden => garden,
        AppTab.journal => journal,
        AppTab.timer || AppTab.settings => null,
      };

  static GlobalKey of(CoachMark mark) => switch (mark) {
        CoachMark.timer => timer,
        CoachMark.garden => garden,
        CoachMark.journal => journal,
      };
}

/// US-003's tutorial: three things worth knowing, said over the running app.
///
/// **Nothing here blocks anything.** There is no barrier and no modal route —
/// the layer is a [Stack] with two children in it, so every pixel the card and
/// its outline do not cover is a pixel the app underneath still receives. A
/// user who wants to pause their session while a coach mark is up taps PAUSE,
/// and the session pauses. That is the requirement, and it is also the reason
/// this is not a `showDialog`.
///
/// One mark is on screen at a time and each is put away on its own; see
/// [OnboardingController.dismissCoachMark].
class CoachMarkLayer extends ConsumerWidget {
  const CoachMarkLayer({required this.mark, super.key});

  final CoachMark mark;

  /// How much air is left between a coach mark and the thing it points at.
  static const double _gap = Spacing.sm;

  /// The gap between the card and the bottom of the screen when the target
  /// cannot be found — clear of the tab bar, which is the one thing at that
  /// edge worth not covering.
  static const double _adrift = 96;

  /// The outline around whatever is being pointed at.
  ///
  /// Drawn only when the target was found, which is what makes it the handle a
  /// test uses to prove that it was: a coach mark that had lost the ring or a
  /// tab destination would still show its card, and would still read as
  /// passing without this.
  static const Key highlightKey = Key('coachMark.highlight');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rect = _targetRect();
    final screen = MediaQuery.sizeOf(context);
    // Whether the thing being pointed at is down at the bottom of the screen,
    // which is where two of the three are: the tab destinations.
    final low = rect == null || rect.center.dy >= screen.height / 2;

    return Stack(
      children: [
        if (rect != null)
          Positioned.fromRect(
            rect: rect.inflate(Spacing.xs),
            child: const IgnorePointer(
              child: _Highlight(key: highlightKey),
            ),
          ),
        Positioned(
          left: Spacing.md,
          right: Spacing.md,
          // A target near the bottom gets its card directly above it. A target
          // higher up — the ring — gets one pinned to the top edge instead of
          // one sitting under it, because what is under the ring is the plant
          // and the two controls: a card that covered PAUSE would be blocking
          // the session it had just congratulated the user for starting.
          top: low ? null : Spacing.md,
          bottom: low
              ? (rect == null ? _adrift : screen.height - rect.top + _gap)
              : null,
          child: _CoachMarkCard(
            mark: mark,
            onDismiss: ref.read(onboardingProvider.notifier).dismissCoachMark,
          ),
        ),
      ],
    );
  }

  /// Where the thing being pointed at is, or null if it cannot be found.
  ///
  /// Read off the render tree the frame before, which is what makes it right on
  /// the first frame the mark appears: every target is already laid out, tab or
  /// no tab, because the shell keeps all four tabs alive. Null is handled
  /// rather than asserted on — a coach mark that could not find the ring should
  /// still say its piece somewhere sensible, not crash a session.
  Rect? _targetRect() {
    final target = CoachMarkTargets.of(mark).currentContext?.findRenderObject();
    if (target is! RenderBox || !target.hasSize) return null;
    return target.localToGlobal(Offset.zero) & target.size;
  }
}

/// The ring drawn around whatever a coach mark is about.
class _Highlight extends StatelessWidget {
  const _Highlight({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
        borderRadius: Radii.mdAll,
      ),
    );
  }
}

/// One coach mark: what the thing is, and the way to put it away.
class _CoachMarkCard extends StatelessWidget {
  const _CoachMarkCard({required this.mark, required this.onDismiss});

  final CoachMark mark;
  final VoidCallback onDismiss;

  /// What each of the three has to say. One sentence apiece, because a tutorial
  /// over a running session is competing with the session.
  static const Map<CoachMark, (String, String)> _copy = {
    CoachMark.timer: (
      'Your first session is growing',
      'The countdown ends on its own — nothing to keep open, nothing to tap. '
          'The seed under it grows the whole way.',
    ),
    CoachMark.garden: (
      'Finished sessions live here',
      'Every session you see through plants something in your garden, and it '
          'stays there.',
    ),
    CoachMark.journal: (
      'And the journal remembers',
      'Your week, your month and everything you have grown — once there is '
          'something to show.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, body) = _copy[mark]!;

    return Semantics(
      container: true,
      child: Card(
        elevation: 6,
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Align(
                alignment: Alignment.centerRight,
                // One control, and it is the dismissal. A coach mark with a
                // Next button would be a slideshow again — this one is put away
                // and whatever comes after it is not this card's business.
                child: TextButton(
                  onPressed: onDismiss,
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
