/// The five visual growth stages. Purely a function of session progress,
/// never stored or entered via events.
enum GrowthStage {
  seed(0, 'Seed'),

  /// 20%.
  sprout(0.2, 'Sprout'),

  /// 50%.
  young(0.5, 'Young'),

  /// 80%.
  maturing(0.8, 'Maturing'),

  /// Complete.
  mature(1, 'Mature');

  const GrowthStage(this.threshold, this.label);

  /// Inclusive.
  final double threshold;

  /// Shown on the plant card.
  final String label;

  /// [progress] is 0 to 1. Out of range clamps; NaN gives [seed].
  static GrowthStage forProgress(double progress) {
    var reached = seed;
    for (final stage in values) {
      if (!(progress >= stage.threshold)) break;
      reached = stage;
    }
    return reached;
  }
}
