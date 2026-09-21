import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/spacing.dart';
import '../../onboarding/onboarding.dart';
import '../../onboarding/onboarding_providers.dart';
import '../../shell/tab.dart';

/// Keys on the real widgets the coach marks point at. Keys rather than
/// coordinates since the layout decides where these end up.
abstract final class CoachMarkTargets {
  /// The plant and countdown on the timer screen.
  static final GlobalKey timer = GlobalKey(debugLabel: 'coachMark.timer');

  static final GlobalKey garden = GlobalKey(debugLabel: 'coachMark.garden');

  static final GlobalKey journal = GlobalKey(debugLabel: 'coachMark.journal');

  /// Null for tabs no coach mark points at.
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

/// The onboarding tips, drawn over the live app. No barrier or modal route:
/// it's a plain [Stack], so taps outside the card still reach the app (PAUSE
/// still works). One mark at a time; see
/// [OnboardingController.dismissCoachMark].
class CoachMarkLayer extends ConsumerStatefulWidget {
  const CoachMarkLayer({required this.mark, super.key});

  final CoachMark mark;

  /// Top of the [CoachMark.timer] card (gap included), in global coordinates.
  /// The timer screen shrinks its pot until the controls sit above this.
  /// Measured, since the card's height depends on text size and width.
  static final ValueNotifier<double?> timerCardTop = ValueNotifier(null);

  static const double _gap = Spacing.sm;

  /// Card offset from the bottom when the target can't be found; clears the
  /// tab bar.
  static const double _adrift = 96;

  /// Only drawn when the target was found, so tests can check that.
  static const Key highlightKey = Key('coachMark.highlight');

  @override
  ConsumerState<CoachMarkLayer> createState() => _CoachMarkLayerState();
}

class _CoachMarkLayerState extends ConsumerState<CoachMarkLayer> {
  final GlobalKey _cardKey = GlobalKey(debugLabel: 'coachMark.card');

  Rect? _drawnAround;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_afterFrame);
  }

  @override
  Widget build(BuildContext context) {
    final rect = _drawnAround = _rectOf(CoachMarkTargets.of(widget.mark));
    // All cards sit just above the tab bar. For the timer mark that's also
    // the only free space; above the pot is the status bar and Dynamic Island.
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

  /// Runs after every frame while the mark is up: reports the timer card's top
  /// and redraws the outline if the target moved (it does while the pot
  /// shrinks). Waits for frames rather than requesting them.
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

  /// Reads last frame's layout. All tabs are kept alive by the shell, so
  /// targets are laid out even on the first frame. Null if not found; the card
  /// still shows.
  static Rect? _rectOf(GlobalKey key) {
    final target = key.currentContext?.findRenderObject();
    if (target is! RenderBox || !target.hasSize) return null;
    return target.localToGlobal(Offset.zero) & target.size;
  }
}

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

class _CoachMarkCard extends StatelessWidget {
  const _CoachMarkCard({
    required this.mark,
    required this.onDismiss,
    super.key,
  });

  final CoachMark mark;
  final VoidCallback onDismiss;

  /// Kept to a sentence each; it's competing with a running session.
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
          // Less at top/right, where the button has its own padding.
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
              // Dismiss button shares the title's line to save height on
              // short phones.
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
                  // Only a dismiss, no Next.
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
