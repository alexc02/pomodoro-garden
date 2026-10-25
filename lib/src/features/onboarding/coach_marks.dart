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
class CoachMarkLayer extends ConsumerStatefulWidget {
  const CoachMarkLayer({required this.mark, super.key});

  final CoachMark mark;

  /// Where the top of [CoachMark.timer]'s card is, gap included, in global
  /// coordinates.
  ///
  /// That card sits above the tab bar like the other two, which is over the
  /// timer's controls: the ring fills the screen down to them. So while it is
  /// up the timer screen shrinks its ring until CANCEL and PAUSE sit above
  /// this line. Measured rather than predicted, because the card's height is
  /// its copy wrapped at the screen's width in the user's text size.
  static final ValueNotifier<double?> timerCardTop = ValueNotifier(null);

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
  ConsumerState<CoachMarkLayer> createState() => _CoachMarkLayerState();
}

class _CoachMarkLayerState extends ConsumerState<CoachMarkLayer> {
  final GlobalKey _cardKey = GlobalKey(debugLabel: 'coachMark.card');

  /// Where the target was when the outline was last drawn around it.
  Rect? _drawnAround;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_afterFrame);
  }

  @override
  Widget build(BuildContext context) {
    final rect = _drawnAround = _rectOf(CoachMarkTargets.of(widget.mark));
    // Every card sits just above the tab bar. Two of the three are about a tab
    // destination, so that is directly above the thing they point at; the
    // ring's sits there too, rather than above the ring, because the room above
    // the ring is the app bar and the phone's status bar and Dynamic Island.
    final anchor = _rectOf(CoachMarkTargets.garden);
    final screen = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        if (rect != null)
          Positioned.fromRect(
            rect: rect.inflate(Spacing.xs),
            child: const IgnorePointer(
              child: _Highlight(key: CoachMarkLayer.highlightKey),
            ),
          ),
        Positioned(
          left: Spacing.md,
          right: Spacing.md,
          bottom: anchor == null
              ? MediaQuery.paddingOf(context).bottom + CoachMarkLayer._adrift
              : screen.height - anchor.top + CoachMarkLayer._gap,
          child: _CoachMarkCard(
            key: _cardKey,
            mark: widget.mark,
            onDismiss: ref.read(onboardingProvider.notifier).dismissCoachMark,
          ),
        ),
      ],
    );
  }

  /// After every frame for as long as the mark is up: reports where the timer
  /// card's top is, and redraws the outline if the target has moved since it
  /// was drawn — which the ring does while the timer screen shrinks it.
  ///
  /// Waits for frames rather than asking for them, so a mark over a screen
  /// that has gone still costs nothing.
  void _afterFrame(Duration _) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback(_afterFrame);
    final card = _cardKey.currentContext?.findRenderObject();
    if (widget.mark == CoachMark.timer && card is RenderBox && card.hasSize) {
      CoachMarkLayer.timerCardTop.value =
          card.localToGlobal(Offset.zero).dy - CoachMarkLayer._gap;
    }
    if (_rectOf(CoachMarkTargets.of(widget.mark)) != _drawnAround) {
      setState(() {});
    }
  }

  /// Where [key]'s widget is on the screen, or null if it cannot be found.
  ///
  /// Read off the render tree the frame before, which is what makes it right on
  /// the first frame the mark appears: every target is already laid out, tab or
  /// no tab, because the shell keeps all four tabs alive. Null is handled
  /// rather than asserted on — a coach mark that could not find the ring should
  /// still say its piece somewhere sensible, not crash a session.
  static Rect? _rectOf(GlobalKey key) {
    final target = key.currentContext?.findRenderObject();
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
  const _CoachMarkCard({
    required this.mark,
    required this.onDismiss,
    super.key,
  });

  final CoachMark mark;
  final VoidCallback onDismiss;

  /// What each of the three has to say. One sentence apiece, because a tutorial
  /// over a running session is competing with the session.
  static const Map<CoachMark, (String, String)> _copy = {
    CoachMark.timer: (
      'Your first session is growing',
      'It ends on its own. Nothing to keep open, nothing to tap.',
    ),
    CoachMark.garden: (
      'Finished sessions live here',
      'Every session you finish plants something here, and it stays.',
    ),
    CoachMark.journal: (
      'And the journal remembers',
      'Your week, your month and everything you\'ve grown, once there\'s '
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
          // Less at the top and the right, where the button's own padding is.
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.xs,
            Spacing.xs,
            Spacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // The dismissal shares the title's line rather than taking one
              // of its own. The ring's card has to fit above the tab bar with
              // the timer's controls still showing over it, and on the
              // shortest phone a line is the difference.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  // One control, and it is the dismissal. A coach mark with a
                  // Next button would be a slideshow again — this one is put
                  // away and whatever comes after it is not this card's
                  // business.
                  TextButton(
                    onPressed: onDismiss,
                    child: const Text('Got it'),
                  ),
                ],
              ),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
