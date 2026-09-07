import 'package:flutter/foundation.dart';

import '../design/garden_colors.dart';
import '../design/garden_skin.dart';

/// The garden partway between one skin and another.
///
/// Theme and season changes share this one value (one clock, one pair of
/// endpoints), so a theme switch mid season-fade can't leave the sky and the
/// soil out of sync. Everything drawn during a change reads colours from here,
/// not from a [GardenSkin].
@immutable
final class GardenTransition {
  const GardenTransition({
    required this.from,
    required this.to,
    required this.progress,
  });

  /// Nothing turning: just [skin].
  const GardenTransition.settled(GardenSkin skin)
      : from = skin,
        to = skin,
        progress = 1;

  final GardenSkin from;

  final GardenSkin to;

  /// 0 is all [from], 1 is all [to].
  final double progress;

  bool get settled => from == to;

  /// [base] with the colours of this moment in it.
  GardenColors applyTo(GardenColors base) {
    final departing = from.applyTo(base);
    if (settled) return departing;

    return departing.lerp(to.applyTo(base), progress);
  }

  @override
  bool operator ==(Object other) =>
      other is GardenTransition &&
      other.from == from &&
      other.to == to &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(from, to, progress);

  @override
  String toString() => 'GardenTransition($from → $to, $progress)';
}
