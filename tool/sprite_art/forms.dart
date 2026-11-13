import 'dart:math' as math;
import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'parts.dart';
import 'plants.dart';
import 'wash.dart';

/// The second shape of the wildflower, the herb and the bush. Each reuses
/// its type's seed and sprout from `plants.dart`, so the two forms only look
/// different from the young stage on.

bool _shared(GrowthStage stage) =>
    stage == GrowthStage.seed || stage == GrowthStage.sprout;

/// 0 young, 0.5 maturing, 1 mature.
double _grown(GrowthStage stage) => switch (stage) {
      GrowthStage.young => 0.0,
      GrowthStage.maturing => 0.5,
      _ => 1.0,
    };

/// The spire (foxglove, bluebell, lupin): a rosette of broad leaves and three
/// tall stems hung with bells, largest at the bottom.
Future<void> paintSpire(Sheet sheet, GrowthStage stage) async {
  if (_shared(stage)) return paintWildflower(sheet, stage);
  await soil(sheet, stage);

  final grown = _grown(stage);
  double between(double a, double b) => a + (b - a) * grown;
  const base = Offset(256, 500);

  // Rosette.
  for (final (i, side, angle) in [
    (0, -1, 0.35),
    (1, 1, 0.4),
    (2, -1, 0.75),
    (3, 1, 0.8),
    (4, -1, 1.15),
    (5, 1, 1.2),
  ]) {
    await leaf(sheet, Offset(256 + side * 3.0, 498),
        side: side,
        angle: angle,
        length: between(40, 66),
        width: between(20, 28),
        seed: 150 + i);
  }

  final tips = [
    Offset(between(238, 208), between(416, 322)),
    Offset(256, between(366, 226)),
    Offset(between(274, 304), between(414, 316)),
  ];
  for (final (i, tip) in tips.indexed) {
    await stalk(sheet, base, tip, width: 8, seed: 30 + i, taper: 3);
  }
  if (stage == GrowthStage.young) return;

  final open = stage == GrowthStage.mature;
  for (final (i, tip) in tips.indexed) {
    // The middle stem carries the most.
    final count = (i == 1 ? 8 : 6) - (open ? 0 : 2);
    for (var k = 0; k < count; k++) {
      final share = k / (count - 1);
      final at = Offset.lerp(base, tip, 0.44 + 0.54 * share)!;
      final size = (open ? 16.0 : 8.0) * (1 - 0.5 * share);
      final side = k.isEven ? -1 : 1;
      await bud(
        sheet,
        at + Offset(side * size * 0.75, size * 0.35),
        rx: size * 0.82,
        ry: size * 1.08,
        seed: 300 + i * 20 + k,
      );
    }
    await bud(sheet, tip + const Offset(0, -3),
        rx: open ? 4.5 : 3.5, ry: open ? 7 : 5, seed: 380 + i);
  }
}

/// The sprig (rosemary, thyme, chives): five upright stems bristling with
/// needles, and a few small flowers near the tips once grown.
Future<void> paintSprig(Sheet sheet, GrowthStage stage) async {
  if (_shared(stage)) return paintHerb(sheet, stage);
  await soil(sheet, stage);

  final grown = _grown(stage);
  double between(double a, double b) => a + (b - a) * grown;
  const base = Offset(256, 500);

  final tips = [
    Offset(between(232, 184), between(424, 338)),
    Offset(between(244, 222), between(404, 298)),
    Offset(256, between(392, 278)),
    Offset(between(268, 290), between(406, 300)),
    Offset(between(280, 328), between(422, 340)),
  ];
  for (final (i, tip) in tips.indexed) {
    await stalk(sheet, base, tip, width: 6, seed: 30 + i, taper: 3);
  }

  final pairs = switch (stage) {
    GrowthStage.young => 5,
    GrowthStage.maturing => 8,
    _ => 11,
  };
  for (final (i, tip) in tips.indexed) {
    for (var pair = 0; pair < pairs; pair++) {
      final at = Offset.lerp(base, tip, 0.22 + 0.78 * pair / (pairs - 1))!;
      for (final side in [-1, 1]) {
        await leaf(sheet, at,
            side: side,
            // Needles point up the stem, a little more so toward the tip.
            angle: 0.75 + 0.25 * pair / pairs,
            length: between(13, 19),
            width: between(6, 7.5),
            seed: 200 + i * 40 + pair * 2 + (side + 1) ~/ 2,
            rib: false);
      }
    }
  }

  if (stage != GrowthStage.mature) return;
  for (final (i, tip) in tips.indexed) {
    for (var f = 0; f < 4; f++) {
      final at = Offset.lerp(base, tip, 1 - 0.09 * f)!;
      await bud(sheet, at + Offset(f.isEven ? -5 : 5, 0),
          rx: 5.5 - f * 0.5, ry: 5.5 - f * 0.5, seed: 400 + i * 5 + f);
    }
  }
}

/// The spiked bush (lavender, heather): a low cushion of leaf with a fan of
/// thin stems standing out of it, each ending in a spike of flowers.
Future<void> paintSpikedBush(Sheet sheet, GrowthStage stage) async {
  if (_shared(stage)) return paintBush(sheet, stage);
  await soil(sheet, stage);

  final scale = switch (stage) {
    GrowthStage.young => 0.5,
    GrowthStage.maturing => 0.75,
    _ => 1.0,
  };
  Offset placed(double x, double y) =>
      Offset(256 + (x - 256) * scale, 500 - (500 - y) * scale);

  // Each stem leaves the cushion at its own foot and leans out from the
  // middle; the middle ones stand tallest.
  const stems = 9;
  final feet = <Offset>[];
  final tips = <Offset>[];
  for (var i = 0; i < stems; i++) {
    final across = i / (stems - 1) * 2 - 1;
    final lean = across * 0.66;
    final length = 208 - 46 * across.abs() + (i.isEven ? 0 : -14);
    final foot = Offset(256 + across * 44, 446);
    feet.add(placed(foot.dx, foot.dy));
    tips.add(placed(
      foot.dx + math.sin(lean) * length,
      foot.dy - math.cos(lean) * length,
    ));
  }
  for (var i = 0; i < stems; i++) {
    await stalk(sheet, feet[i], tips[i],
        width: 4 * scale + 2,
        seed: 40 + i,
        taper: 2,
        bend: i < stems ~/ 2 ? 0.04 : -0.04);
  }

  // (x, y, rx, ry) of the cushion, back first.
  const cushion = [
    (256.0, 428.0, 70.0, 44.0),
    (198.0, 448.0, 58.0, 40.0),
    (314.0, 448.0, 58.0, 40.0),
    (256.0, 462.0, 78.0, 34.0),
  ];
  for (final (i, (x, y, rx, ry)) in cushion.indexed) {
    await clump(sheet, placed(x, y),
        rx: rx * scale, ry: ry * scale, seed: 500 + i, lobes: 9);
  }

  if (stage == GrowthStage.young) return;
  final open = stage == GrowthStage.mature;
  final florets = open ? 6 : 3;
  for (var i = 0; i < stems; i++) {
    for (var f = 0; f < florets; f++) {
      // From partway up the stem to just past the tip, shrinking.
      final t = (open ? 0.64 : 0.82) + 0.075 * f;
      final at = Offset.lerp(feet[i], tips[i], t)!;
      final size = (open ? 10.5 : 7.0) * (1 - 0.09 * f) * scale;
      await bud(sheet, at + Offset(f.isEven ? -2.5 : 2.5, 0) * scale,
          rx: size * 0.82, ry: size, seed: 600 + i * 10 + f);
    }
  }
}
