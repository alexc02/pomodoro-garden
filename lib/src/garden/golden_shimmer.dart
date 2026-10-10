import 'dart:math' as math;
import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

/// REQ-021's golden garden: once the thousandth session has been reached,
/// every plant in the garden shimmers (PRD v2.2).
///
/// A warm gold laid over each plant in the garden's one batched draw
/// (`GardenAtlas.drawInto`'s per-sprite colours), so the shimmer adds no quad
/// and no draw call (ADR 0020). It rises and falls on the same shared loop the
/// sway runs on, but on a phase of its own per plant, so the garden glints here
/// and there rather than pulsing in unison — and not in step with each plant's
/// lean, which would make the two read as one motion.
///
/// Held still when the garden is held still (the system's reduce-motion
/// setting, or an export): a steady warm tint, so the award is still visible.
abstract final class GoldenShimmer {
  /// The gold the plants are washed with.
  static const Color gold = Color(0xFFF2C14E);

  /// How strong the wash is on a garden holding still.
  static const double still = 0.18;

  /// The faintest and the strongest the wash gets while it moves.
  static const double faintest = 0.08;
  static const double strongest = 0.26;

  /// The gold wash on the plant identified by [seed], when the shared loop is
  /// [turn] of the way through, or held still when [turn] is null.
  static Color tintAt(double? turn, {required String seed}) =>
      gold.withValues(alpha: strengthAt(turn, seed: seed));

  /// How strong the wash is: [still] when there is no motion, otherwise
  /// between [faintest] and [strongest].
  static double strengthAt(double? turn, {required String seed}) {
    if (turn == null) return still;
    final wave = 0.5 +
        0.5 * math.sin((turn + stableFraction('$seed/shimmer')) * 2 * math.pi);
    return faintest + (strongest - faintest) * wave;
  }

  /// Whether [garden] has earned the shimmer: the golden garden is in it.
  static bool earnedBy(GardenLayout garden) => garden.bonusPlants
      .any((plant) => plant.milestone == Milestone.oneThousand);
}
