/// How far along a plant looks: REQ-016's five visual stages.
///
/// A pure function of how far through its session the plant is, and nothing
/// else. No stage is *entered* — there is no event, no callback and no stored
/// "current stage" that could fall out of step with the clock. Ask what the
/// stage is at a given progress and the answer is the same whether the app was
/// watching the whole time or has just been opened. That is the same discipline
/// the session machine applies to elapsed time, for the same reason.
enum GrowthStage {
  /// Session starts. A small dot in the soil.
  seed(0, 'Seed'),

  /// 20% through. A tiny green shoot.
  sprout(0.2, 'Sprout'),

  /// 50% through. A recognisable plant shape.
  young(0.5, 'Young'),

  /// 80% through. Near full size, before the bloom.
  maturing(0.8, 'Maturing'),

  /// The session is complete. Full bloom, full size.
  mature(1, 'Mature');

  const GrowthStage(this.threshold, this.label);

  /// The progress at which a plant reaches this stage. Inclusive: progress of
  /// exactly [threshold] is already this stage.
  final double threshold;

  /// What to call this stage in front of the user — ticket 12's card shows it.
  final String label;

  /// The stage a plant is at when its session is [progress] of the way through,
  /// 0 to 1.
  ///
  /// Total for every double, including the ones that should not arrive.
  /// Progress outside 0..1 clamps to the ends; a NaN reads as a seed, because
  /// every comparison against NaN is false and the honest answer to "how grown
  /// is a plant whose progress is not a number" is "not at all".
  static GrowthStage forProgress(double progress) {
    var reached = seed;
    for (final stage in values) {
      if (!(progress >= stage.threshold)) break;
      reached = stage;
    }
    return reached;
  }
}
