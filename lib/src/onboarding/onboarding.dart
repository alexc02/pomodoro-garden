/// REQ-003's three steps, in the order the user meets them.
///
/// Three and no more, which is the requirement: a welcome with a garden to look
/// at, the one choice worth making before a first session, and the tap that
/// starts it. There is no fourth step to add a feature to — anything a later
/// ticket wants to teach belongs in a [CoachMark], over the running app.
enum OnboardingStep {
  /// What the app is for, and what a garden looks like once it has been used.
  welcome,

  /// The one decision: how long the first session runs. REQ-004, US-004.
  sessionLength,

  /// The tap. Nothing on this step but what is about to happen.
  start;

  /// The step after this one, or null if this is the last.
  OnboardingStep? get next {
    final at = index + 1;
    return at < values.length ? values[at] : null;
  }
}

/// US-003's three things worth knowing, taught over the running app rather than
/// in a slideshow.
///
/// One per tab the user has not met yet, plus the one they are looking at. They
/// are shown one at a time, in this order, and each is put away on its own —
/// a user who dismisses the first never sees the other two, which is the point
/// of dismissing it.
enum CoachMark {
  /// The countdown they just started, and the plant under it.
  timer,

  /// Where the plant goes when the session finishes.
  garden,

  /// What the app remembers about the work, once there is any.
  journal;

  /// The mark after this one, or null if this is the last.
  CoachMark? get next {
    final at = index + 1;
    return at < values.length ? values[at] : null;
  }
}

/// Where the user is in onboarding: one of the three steps, one of the three
/// coach marks, or past all of it.
///
/// One value rather than two flags, because the three states are exclusive and
/// a screen asking "is a step showing" should not have to also ask "and is a
/// coach mark showing over it". The invariant — at most one of [step] and
/// [mark] is set — is held by the constructors rather than checked, so there is
/// no way to build a progress that claims both.
final class OnboardingProgress {
  /// Showing [step] of the flow, over the app.
  const OnboardingProgress.atStep(OnboardingStep this.step) : mark = null;

  /// Showing [mark] over the app, with the first session already running.
  const OnboardingProgress.coaching(CoachMark this.mark) : step = null;

  const OnboardingProgress._()
      : step = null,
        mark = null;

  /// Nothing to show: the user has been through onboarding, or skipped it, or
  /// installed the app before it existed.
  static const OnboardingProgress done = OnboardingProgress._();

  /// The step on screen, or null when none is.
  final OnboardingStep? step;

  /// The coach mark on screen, or null when none is.
  final CoachMark? mark;

  /// Whether onboarding has anything left to show.
  bool get isDone => step == null && mark == null;

  @override
  bool operator ==(Object other) =>
      other is OnboardingProgress && other.step == step && other.mark == mark;

  @override
  int get hashCode => Object.hash(step, mark);

  @override
  String toString() => switch ((step, mark)) {
        (final OnboardingStep step, _) => 'OnboardingProgress(${step.name})',
        (_, final CoachMark mark) => 'OnboardingProgress(coaching ${mark.name})',
        _ => 'OnboardingProgress(done)',
      };
}
