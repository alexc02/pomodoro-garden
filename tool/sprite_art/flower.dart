import 'dart:math' as math;
import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'parts.dart';
import 'wash.dart';

/// Flower type (sunflower, tulip, daisy) at each stage. Leaves keep their
/// position and seed across stages and just get bigger, so it reads as one
/// plant growing. Species differ only by palette.
Future<void> paintFlower(Sheet sheet, GrowthStage stage) async {
  final s = sheet.side / 512;
  final ground = Offset(256 * s, 512 * s);

  await soil(sheet, stage);
  if (stage == GrowthStage.seed) return;

  final plan = _plans[stage]!;
  final base = ground + Offset(0, -10 * s);
  final top = Offset(256 * s + plan.lean * s, plan.top * s);

  await sheet.wash(
    wobbly(
      along(base, top, width: (t) => (plan.stem - 2.5 * t) * s, bend: 0.025),
      seed: 21,
      amplitude: 0.7 * s * sheet.finish.wobble,
    ),
    role: Role.foliage,
    seed: 21,
    depth: 0.24,
    rim: 0.3,
  );

  for (final it in plan.leaves) {
    await leaf(
      sheet,
      Offset.lerp(base, top, it.at)! / s,
      side: it.side,
      angle: it.angle,
      length: it.length,
      width: it.width,
      seed: it.seed,
    );
  }

  switch (stage) {
    case GrowthStage.seed:
      break;
    case GrowthStage.sprout:
      break;
    case GrowthStage.young:
      await _bud(sheet, top, s, size: 1, coloured: 0.25);
    case GrowthStage.maturing:
      await _bud(sheet, top, s, size: 1.6, coloured: 0.7);
    case GrowthStage.mature:
      await _bloom(sheet, top, s);
  }
}

/// Per-stage layout on the 512 grid.
final Map<GrowthStage, _Plan> _plans = {
  GrowthStage.sprout: const _Plan(top: 440, stem: 5, lean: 2, leaves: [
    _Leaf(at: 1, side: -1, angle: 0.55, length: 30, width: 20, seed: 101),
    _Leaf(at: 1, side: 1, angle: 0.65, length: 28, width: 19, seed: 102),
  ]),
  GrowthStage.young: const _Plan(top: 300, stem: 7, lean: 3, leaves: [
    _Leaf(at: 0.3, side: -1, angle: 0.45, length: 48, width: 26, seed: 201),
    _Leaf(at: 0.34, side: 1, angle: 0.5, length: 46, width: 25, seed: 202),
    _Leaf(at: 0.62, side: 1, angle: 0.6, length: 36, width: 20, seed: 203),
    _Leaf(at: 0.66, side: -1, angle: 0.62, length: 34, width: 19, seed: 204),
  ]),
  GrowthStage.maturing: const _Plan(top: 205, stem: 8, lean: 4, leaves: [
    _Leaf(at: 0.2, side: -1, angle: 0.42, length: 64, width: 34, seed: 201),
    _Leaf(at: 0.24, side: 1, angle: 0.48, length: 62, width: 32, seed: 202),
    _Leaf(at: 0.47, side: 1, angle: 0.55, length: 54, width: 29, seed: 203),
    _Leaf(at: 0.51, side: -1, angle: 0.58, length: 52, width: 28, seed: 204),
    _Leaf(at: 0.72, side: -1, angle: 0.66, length: 40, width: 21, seed: 205),
    _Leaf(at: 0.75, side: 1, angle: 0.7, length: 38, width: 20, seed: 206),
  ]),
  GrowthStage.mature: const _Plan(top: 175, stem: 10, lean: 4, leaves: [
    _Leaf(at: 0.18, side: -1, angle: 0.4, length: 76, width: 39, seed: 201),
    _Leaf(at: 0.22, side: 1, angle: 0.46, length: 74, width: 38, seed: 202),
    _Leaf(at: 0.43, side: 1, angle: 0.52, length: 66, width: 34, seed: 203),
    _Leaf(at: 0.47, side: -1, angle: 0.55, length: 64, width: 32, seed: 204),
    _Leaf(at: 0.66, side: -1, angle: 0.64, length: 50, width: 26, seed: 205),
    _Leaf(at: 0.69, side: 1, angle: 0.68, length: 48, width: 25, seed: 206),
  ]),
};

final class _Plan {
  const _Plan({
    required this.top,
    required this.stem,
    required this.lean,
    required this.leaves,
  });

  /// Stem tip, pixels from the top.
  final double top;

  /// Stem width at the foot.
  final double stem;

  /// Stem tip offset right of centre.
  final double lean;

  final List<_Leaf> leaves;
}

final class _Leaf {
  const _Leaf({
    required this.at,
    required this.side,
    required this.angle,
    required this.length,
    required this.width,
    required this.seed,
  });

  /// 0 at the soil, 1 at the top of the stem.
  final double at;

  /// -1 left, 1 right.
  final int side;

  /// Radians above horizontal.
  final double angle;

  final double length;
  final double width;
  final int seed;
}

/// Bud with green sepals around a coloured tip.
Future<void> _bud(
  Sheet sheet,
  Offset top,
  double s, {
  required double size,
  required double coloured,
}) async {
  final centre = top + Offset(0, -12 * s * size);

  await sheet.wash(
    wobbly(ellipse(centre, 11 * s * size, 17 * s * size), seed: 301,
        amplitude: 0.9 * s * sheet.finish.wobble),
    role: Role.bloom,
    seed: 301,
    depth: 0.12,
    rim: 0.5,
  );

  // Sepals open wider as the bud colours.
  final open = 0.35 + 0.5 * coloured;
  for (final side in [-1, 1]) {
    final tip = centre +
        Offset(side * 12 * s * size * open, -6 * s * size * (1 - coloured));
    await sheet.wash(
      wobbly(
        along(top + Offset(0, 2 * s), tip,
            width: leafProfile(10 * s * size), bend: 0.2 * side),
        seed: 310 + side,
        amplitude: 0.7 * s * sheet.finish.wobble,
      ),
      role: Role.foliage,
      seed: 310 + side,
      depth: 0.16,
      rim: 0.45,
    );
  }
}

/// Two rings of petals around a seed head.
Future<void> _bloom(Sheet sheet, Offset top, double s) async {
  final centre = top + Offset(0, -4 * s);
  final random = math.Random(401);

  for (final (ring, count, length, width, depth, turn) in [
    (0, 11, 60.0, 32.0, 0.12, 0.0),
    (1, 11, 42.0, 26.0, 0.22, 0.5),
  ]) {
    for (var i = 0; i < count; i++) {
      final angle = (i + turn) / count * 2 * math.pi +
          (random.nextDouble() - 0.5) * 0.12;
      final reach = length * (0.9 + random.nextDouble() * 0.2) * s;
      final from = centre + Offset(math.cos(angle), math.sin(angle)) * 6 * s;
      final to = centre + Offset(math.cos(angle), math.sin(angle)) * reach;
      final seed = 420 + ring * 50 + i;
      await sheet.wash(
        wobbly(
          along(from, to,
              width: petalProfile(width * s),
              bend: (random.nextDouble() - 0.5) * 0.12),
          seed: seed,
          amplitude: 1.8 * s * sheet.finish.wobble,
        ),
        role: Role.bloom,
        seed: seed,
        depth: depth,
        rim: 0.45,
        // Darker toward the centre.
        shade: (x, y) {
          final p = Offset(x, y) * sheet.side.toDouble();
          final out = ((p - centre).distance / reach).clamp(0.0, 1.0);
          return 0.2 * (1 - out);
        },
      );
    }
  }

  await sheet.wash(
    wobbly(
      ellipse(centre, 23 * s, 22 * s),
      seed: 480,
      amplitude: wobbleOf(sheet, 1.0),
    ),
    role: Role.soil,
    seed: 480,
    depth: 0.37,
    rim: 0.35,
    mottle: 0.2,
  );
}
