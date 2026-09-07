import 'dart:math' as math;
import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

/// The gold shimmer every plant gets once the 1000th session is reached.
///
/// Applied through the atlas's per-sprite colours, so it costs no extra quads
/// or draw calls. Runs on the sway loop but with its own per-plant
/// phase so plants glint independently and out of step with their lean. With
/// motion off (reduce-motion, export) it's a steady tint.
abstract final class GoldenShimmer {
  static const Color gold = Color(0xFFF2C14E);

  /// Wash strength when the garden is holding still.
  static const double still = 0.18;

  /// Range of the wash while it moves.
  static const double faintest = 0.08;
  static const double strongest = 0.26;

  /// The wash for the plant identified by [seed] at loop position [turn]
  /// (null means held still).
  static Color tintAt(double? turn, {required String seed}) =>
      gold.withValues(alpha: strengthAt(turn, seed: seed));

  static double strengthAt(double? turn, {required String seed}) {
    if (turn == null) return still;
    final wave = 0.5 +
        0.5 * math.sin((turn + stableFraction('$seed/shimmer')) * 2 * math.pi);
    return faintest + (strongest - faintest) * wave;
  }

  /// True once the golden-garden bonus plant is in [garden].
  static bool earnedBy(GardenLayout garden) => garden.bonusPlants
      .any((plant) => plant.milestone == Milestone.oneThousand);
}
