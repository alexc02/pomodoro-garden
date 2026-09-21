import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/onboarding_providers.dart';
import 'coach_marks.dart';
import 'onboarding_steps.dart';

/// Draws onboarding over the app: the three steps, then coach marks over the
/// running session. The shell is alive underneath the whole time.
///
/// The [Stack] is always there, even after onboarding, so the shell's element
/// (running session, garden camera, plant animations) survives. Returning the
/// bare child would rebuild the app and replay the seed drop.
class OnboardingOverlay extends ConsumerWidget {
  const OnboardingOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(onboardingProvider);
    // During a step the app underneath takes no taps and isn't read out.
    // The wrappers stay in the tree with flags flipped, for the same reason
    // as the Stack. Coach marks set neither; they sit on the app, not in
    // front of it.
    final covered = progress.step != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: covered,
          child: ExcludeSemantics(excluding: covered, child: child),
        ),
        if (progress.step case final step?)
          Positioned.fill(child: OnboardingSteps(step: step)),
        if (progress.mark case final mark?)
          Positioned.fill(child: CoachMarkLayer(mark: mark)),
      ],
    );
  }
}
