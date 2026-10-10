import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/onboarding_providers.dart';
import 'coach_marks.dart';
import 'onboarding_steps.dart';

/// Puts onboarding over the app: REQ-003's three steps first, then US-003's
/// coach marks over the running session.
///
/// **The app is underneath the whole time.** The shell is built and alive
/// behind the welcome screen, which is what makes the hand-off at the end of
/// the flow a card being taken away rather than a screen being pushed — the
/// timer the user lands on is the timer that was already there, and the seed
/// that drops on it (US-005) drops into a garden that has been in the tree
/// since launch.
///
/// **The [Stack] is unconditional, and that is load-bearing.** Onboarding
/// finishing changes which children are in it and never the shape of the tree,
/// so the shell's element — the running session, the garden's camera, the
/// plant's animations — survives the last coach mark being put away. A version
/// of this that returned the bare child once onboarding was done would rebuild
/// the app from scratch at the end of the flow, and the first thing the user
/// would see is their seed dropping a second time.
class OnboardingOverlay extends ConsumerWidget {
  const OnboardingOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(onboardingProvider);
    // While one of the three steps is up, the app underneath is scenery: it
    // takes no taps and is not read out. Both wrappers stay in the tree with
    // their flags flipped rather than appearing and disappearing, for the
    // reason the [Stack] is unconditional.
    //
    // A coach mark sets neither of them, and that is the difference between
    // the two halves of onboarding: a step is in front of the app and a coach
    // mark is on it.
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
