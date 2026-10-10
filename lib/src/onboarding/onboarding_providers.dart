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

/// Where the user is in onboarding, and the only thing that decides whether
/// anything of it is on screen.
final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingProgress>(
  OnboardingController.new,
);

/// Walks the user from a first launch to a running session, and then out of the
/// way.
///
/// **The stored flag is read once, at the start of the run, and not watched.**
/// Finishing onboarding writes it, and a controller that watched it would tear
/// its own state down mid-flow — the coach marks are shown *after* the flag is
/// written, so watching it would mean the first session dismissing them.
///
/// **Every step is skippable and skipping means skipping.** [skip] leaves the
/// whole of onboarding behind, coach marks included, on the settings the user
/// already has. A user who says no to a welcome screen has not asked to be
/// taught three things about the app afterwards.
class OnboardingController extends Notifier<OnboardingProgress> {
  /// When the user met the welcome screen, or null if they never did.
  ///
  /// The other half of §7.1's `time_to_first_session`, and the reason it is a
  /// stored instant rather than a stopwatch: onboarding is a layer over the
  /// running app, so the flow can sit on screen across a trip to the background
  /// and the honest answer is how long the user took, not how long this app was
  /// awake for.
  DateTime? _metAt;

  @override
  OnboardingProgress build() {
    if (ref.read(settingsProvider).onboardingCompleted) {
      return OnboardingProgress.done;
    }

    _metAt = ref.read(clockProvider).now();
    return const OnboardingProgress.atStep(OnboardingStep.welcome);
  }

  /// Moves to the next step, or — from the last one — off the end of the flow.
  ///
  /// The last step's own control is [startFirstSession]; this reaching the end
  /// is the *skip* path arriving there, which finishes onboarding without
  /// starting anything.
  void advance() {
    final next = state.step?.next;
    if (next == null) {
      skip();
      return;
    }
    state = OnboardingProgress.atStep(next);
  }

  /// REQ-003's second step: the length the first session will run for.
  ///
  /// Written to settings there and then rather than held until START, which is
  /// what makes it *the* session length and not an onboarding-only value —
  /// the timer behind this screen is already showing it, and it is what the
  /// user's next session runs for too.
  void chooseLength(Duration length) =>
      _change((settings) => settings.withSessionLength(length));

  /// REQ-003's third step: the session, and everything that follows from it.
  ///
  /// In this order, and the order is the whole of it: the length is settled
  /// before the session is started, because [SessionController.start] reads the
  /// setting once and keeps it for the life of the session; the timer tab is
  /// selected before the session starts, so the seed of US-005 drops on a
  /// screen the user is looking at; and the coach marks come last, over a
  /// session that is already running.
  void startFirstSession() {
    // Every step behind them, and the time it took to get here — §7.1's
    // `onboarding_completed`, recorded before the session so that the log reads
    // in the order the user lived it.
    _finish(
      stepsCompleted: OnboardingStep.values.length,
      reachedASession: true,
    );
    ref.read(selectedTabProvider.notifier).select(AppTab.timer);
    unawaited(ref.read(sessionControllerProvider.notifier).start());
    state = const OnboardingProgress.coaching(CoachMark.timer);
  }

  /// Leaves onboarding, from whichever step the user was on.
  ///
  /// Nothing is started and no coach mark follows. The session length keeps
  /// whatever value it had — REQ-002's 25 minutes, for a user who skipped the
  /// step that offered to change it — and the user lands on the app itself,
  /// where START is one tap away.
  void skip() {
    // The steps behind them, which is the index of the one they walked out of:
    // leaving the welcome screen completes none, and leaving the last one
    // completes the two before it. A skip reaches no session, so there is no
    // time to one.
    _finish(
      stepsCompleted: state.step?.index ?? OnboardingStep.values.length,
      reachedASession: false,
    );
    state = OnboardingProgress.done;
  }

  /// Puts away the coach mark on screen and shows the next one, or none.
  ///
  /// Each is dismissed on its own, and dismissing one is not a promise to look
  /// at the next: a user who has put all three away has finished with them, and
  /// so has a user who tapped through the first and then ignored the rest —
  /// nothing here waits for anything.
  void dismissCoachMark() {
    final next = state.mark?.next;
    state = next == null
        ? OnboardingProgress.done
        : OnboardingProgress.coaching(next);
  }

  /// Shows onboarding again, from the beginning.
  ///
  /// The documented way to see it twice, and the only caller is the settings
  /// screen's debug section — which is compiled out of release builds. It
  /// writes the flag as well as moving the state, so the flow is still there
  /// after a relaunch rather than only until this run of the app ends.
  void reset() {
    _change((settings) => settings.withOnboardingReset());
    // A second run through the flow is timed from where it starts, not from the
    // launch that decided the user had already been through it.
    _metAt = ref.read(clockProvider).now();
    state = const OnboardingProgress.atStep(OnboardingStep.welcome);
  }

  /// Records that the user has been through onboarding, in settings and in
  /// §7.1's log.
  ///
  /// Called when the flow is left by any route — started or skipped — because
  /// both are the user having met it, and REQ-003's "shows once" is about the
  /// screen rather than about the session. The event is recorded on both routes
  /// for the same reason: what §7.1 is measuring is the friction, and a user
  /// who walked out on step one is the measurement.
  void _finish({required int stepsCompleted, required bool reachedASession}) {
    _change((settings) => settings.withOnboardingCompleted());

    final met = _metAt;
    // Null only if something reached this without the flow ever being on
    // screen, which no route does. Nothing to say about a first run that did
    // not happen, so nothing is said.
    if (met == null) return;

    final took = ref.read(clockProvider).now().difference(met);
    ref.read(analyticsProvider).record(OnboardingCompleted(
          stepsCompleted: stepsCompleted,
          timeToFirstSession: reachedASession ? took : null,
        ));
    _metAt = null;
  }

  /// Applies [edit] to the settings as they stand now.
  ///
  /// Not awaited, for the reason the settings screen does not await its own
  /// writes: the new value is live before the write finishes, which is what
  /// lets [startFirstSession] read the length it has just chosen, and a failed
  /// write reports itself.
  void _change(GardenSettings Function(GardenSettings) edit) {
    final controller = ref.read(settingsControllerProvider.notifier);
    unawaited(controller.change(edit(ref.read(settingsProvider))));
  }
}
