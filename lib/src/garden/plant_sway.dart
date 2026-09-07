import 'dart:math' as math;

import 'package:pomodoro_domain/pomodoro_domain.dart';

/// The ambient sway (2 degrees on a 4s loop, offset per plant) as plain math.
///
/// [GrowingPlant] and [GardenPainter]'s atlas batch render it completely
/// differently but must match exactly, or the plant you watched grow on the
/// timer would move differently in the garden. So both ask this.
///
/// The whole garden runs off one controller, so the per-plant phase is what
/// stops everything leaning in unison. It's derived via [stableFraction], so
/// it never re-rolls.
final class PlantSway {
  const PlantSway._();

  /// One full sway, out and back.
  static const Duration period = Duration(seconds: 4);

  /// 2 degrees, in radians.
  static const double amplitude = 2 * math.pi / 180;

  /// Loop offset for the plant identified by [seed], as a fraction of a
  /// period.
  ///
  /// Callers pass the plant's session id where it has one (so it matches
  /// [GrowingPlant]); bonus plants have no session and use their own id.
  static double phaseOf(String seed) => stableFraction(seed);

  /// Lean in radians at loop position [turn] (0 to 1, wraps seamlessly).
  ///
  /// A sine is already slowest at the extremes, so no easing curve needed.
  /// [amount] (0 to 1) scales the lean: used to fade a newly mature plant in,
  /// and set to 0 for reduce-motion.
  static double leanAt(
    double turn, {
    required String seed,
    double amount = 1,
  }) =>
      math.sin((turn + phaseOf(seed)) * 2 * math.pi) * amplitude * amount;
}
