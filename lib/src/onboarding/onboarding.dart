/// The three onboarding steps, in order. Deliberately capped at three;
/// anything else to teach goes in a [CoachMark].
enum OnboardingStep {
  welcome,

  /// Picks how long the first session runs.
  sessionLength,

  start;

  /// The step after this one, or null if this is the last.
  OnboardingStep? get next {
    final at = index + 1;
    return at < values.length ? values[at] : null;
  }
}

/// Hints shown over the running app, one at a time in this order. Dismissing
/// one skips the rest.
enum CoachMark {
  timer,
  garden,
  journal;

  /// The mark after this one, or null if this is the last.
  CoachMark? get next {
    final at = index + 1;
    return at < values.length ? values[at] : null;
  }
}

/// Where the user is in onboarding: a step, a coach mark, or done.
///
/// At most one of [step] and [mark] is set; the constructors guarantee it.
final class OnboardingProgress {
  const OnboardingProgress.atStep(OnboardingStep this.step) : mark = null;

  /// Showing [mark] with the first session already running.
  const OnboardingProgress.coaching(CoachMark this.mark) : step = null;

  const OnboardingProgress._()
      : step = null,
        mark = null;

  /// Finished, skipped, or installed before onboarding existed.
  static const OnboardingProgress done = OnboardingProgress._();

  final OnboardingStep? step;

  final CoachMark? mark;

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
