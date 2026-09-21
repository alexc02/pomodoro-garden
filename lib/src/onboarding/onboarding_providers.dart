import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../analytics/analytics_providers.dart';
import '../session/session_providers.dart';
import '../settings/settings_providers.dart';
import '../shell/shell_providers.dart';
import '../shell/tab.dart';
import '../time/clock_provider.dart';
import 'onboarding.dart';

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingProgress>(
  OnboardingController.new,
);

/// First launch through to a running session, then the coach marks.
///
/// Reads the stored flag once, not watched: the flag is written before the
/// coach marks show, so watching it would dismiss them. [skip] skips
/// everything, coach marks included.
class OnboardingController extends Notifier<OnboardingProgress> {
  /// When the welcome screen was shown, for `time_to_first_session`. An
  /// instant rather than a stopwatch so time in the background counts.
  DateTime? _metAt;

  @override
  OnboardingProgress build() {
    if (ref.read(settingsProvider).onboardingCompleted) {
      return OnboardingProgress.done;
    }

    _metAt = ref.read(clockProvider).now();
    return const OnboardingProgress.atStep(OnboardingStep.welcome);
  }

  /// Past the last step this acts as [skip]; the last step's real action is
  /// [startFirstSession].
  void advance() {
    final next = state.step?.next;
    if (next == null) {
      skip();
      return;
    }
    state = OnboardingProgress.atStep(next);
  }

  /// Saved straight to settings; it's the real session length, not an
  /// onboarding-only value.
  void chooseLength(Duration length) =>
      _change((settings) => settings.withSessionLength(length));

  /// Order matters: the length is already in settings (read once by
  /// [SessionController.start]), the timer tab is selected before starting so
  /// the seed drop is visible, and coach marks come last.
  void startFirstSession() {
    // Before starting, so the log is in order.
    _finish(
      stepsCompleted: OnboardingStep.values.length,
      reachedASession: true,
    );
    ref.read(selectedTabProvider.notifier).select(AppTab.timer);
    unawaited(ref.read(sessionControllerProvider.notifier).start());
    state = const OnboardingProgress.coaching(CoachMark.timer);
  }

  /// Leaves onboarding from any step. Starts nothing, no coach marks.
  void skip() {
    // Steps completed = index of the step they left.
    _finish(
      stepsCompleted: state.step?.index ?? OnboardingStep.values.length,
      reachedASession: false,
    );
    state = OnboardingProgress.done;
  }

  void dismissCoachMark() {
    final next = state.mark?.next;
    state = next == null
        ? OnboardingProgress.done
        : OnboardingProgress.coaching(next);
  }

  /// Debug only (settings debug section). Clears the stored flag too, so it
  /// survives a relaunch.
  void reset() {
    _change((settings) => settings.withOnboardingReset());
    _metAt = ref.read(clockProvider).now();
    state = const OnboardingProgress.atStep(OnboardingStep.welcome);
  }

  /// Marks onboarding done and logs `onboarding_completed`, whether started
  /// or skipped (a skip is still worth measuring).
  void _finish({required int stepsCompleted, required bool reachedASession}) {
    _change((settings) => settings.withOnboardingCompleted());

    final met = _metAt;
    // Shouldn't happen: every route here showed the flow.
    if (met == null) return;

    final took = ref.read(clockProvider).now().difference(met);
    ref.read(analyticsProvider).record(OnboardingCompleted(
          stepsCompleted: stepsCompleted,
          timeToFirstSession: reachedASession ? took : null,
        ));
    _metAt = null;
  }

  /// Not awaited; `change` updates state synchronously and reports its own
  /// write failures.
  void _change(GardenSettings Function(GardenSettings) edit) {
    final controller = ref.read(settingsControllerProvider.notifier);
    unawaited(controller.change(edit(ref.read(settingsProvider))));
  }
}
