import 'dart:math' as math;
import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'parts.dart';
import 'wash.dart';

/// REQ-015's other five types and the bonus plant, through REQ-016's five
/// stages, cut from the same pieces as the flower (`flower.dart`).
///
/// Every type stands on the same soil and starts from the same seed. After
/// that each keeps its pieces' places and seeds from stage to stage, so a
/// later stage is the earlier one grown, not a new drawing.

/// REQ-015's **wildflower** (5–14 minutes): small and colourful, a quick bloom.
/// Three thin stems fanning from a tuft of grass, each ending in a five-petal
/// flower.
Future<void> paintWildflower(Sheet sheet, GrowthStage stage) async {
  await soil(sheet, stage);
  if (stage == GrowthStage.seed) return;

  const base = Offset(256, 500);
  if (stage == GrowthStage.sprout) {
    await stalk(sheet, base, const Offset(257, 468), width: 4, seed: 21);
    await leaf(sheet, const Offset(257, 470),
        side: -1, angle: 0.7, length: 18, width: 13, seed: 101, rib: false);
    await leaf(sheet, const Offset(257, 470),
        side: 1, angle: 0.8, length: 17, width: 12, seed: 102, rib: false);
    return;
  }

  final grown = switch (stage) {
    GrowthStage.young => 0.0,
    GrowthStage.maturing => 0.5,
    _ => 1.0,
  };
  double between(double a, double b) => a + (b - a) * grown;

  // The grass the stems rise out of: long, steep blades.
  for (final (i, side, angle) in [
    (0, -1, 0.95),
    (1, 1, 1.0),
    (2, -1, 1.2),
    (3, 1, 1.25),
    (4, -1, 1.45),
    (5, 1, 1.5),
  ]) {
    await leaf(sheet, Offset(256 + side * 4.0, 500),
        side: side,
        angle: angle,
        length: between(44, 64),
        width: 17,
        seed: 150 + i,
        rib: false);
  }

  final tips = [
    Offset(between(222, 194), between(392, 340)),
    Offset(between(240, 228), between(366, 300)),
    Offset(256, between(350, 282)),
    Offset(between(274, 286), between(368, 304)),
    Offset(between(290, 318), between(390, 336)),
  ];
  for (final (i, tip) in tips.indexed) {
    await stalk(sheet, base, tip, width: 6, seed: 30 + i, taper: 2);
  }

  for (final (i, tip) in tips.indexed) {
    switch (stage) {
      case GrowthStage.young:
        break;
      case GrowthStage.maturing:
        await bud(sheet, tip + const Offset(0, -7), rx: 9, ry: 12, seed: 60 + i);
      default:
        await blossom(sheet, tip + const Offset(0, -10),
            radius: 27, seed: 70 + i * 10, turn: i * 0.6);
    }
  }
}

/// REQ-015's **herb** (15–24 minutes): basil, mint, rosemary — medium height,
/// textured. Three stems thick with rounded leaves in pairs, and a spike of
/// flowers on each once it is grown.
Future<void> paintHerb(Sheet sheet, GrowthStage stage) async {
  await soil(sheet, stage);
  if (stage == GrowthStage.seed) return;

  const base = Offset(256, 500);
  if (stage == GrowthStage.sprout) {
    await stalk(sheet, base, const Offset(256, 470), width: 5, seed: 21);
    await leaf(sheet, const Offset(256, 472),
        side: -1, angle: 0.5, length: 20, width: 17, seed: 101, round: true);
    await leaf(sheet, const Offset(256, 472),
        side: 1, angle: 0.55, length: 20, width: 17, seed: 102, round: true);
    return;
  }

  final (pairs, reach, size) = switch (stage) {
    GrowthStage.young => (2, 0.0, 26.0),
    GrowthStage.maturing => (3, 0.5, 31.0),
    _ => (4, 1.0, 36.0),
  };
  double between(double a, double b) => a + (b - a) * reach;

  final tips = [
    Offset(between(226, 196), between(402, 318)),
    Offset(256, between(380, 280)),
    Offset(between(286, 316), between(400, 316)),
  ];

  for (final (i, tip) in tips.indexed) {
    await stalk(sheet, base, tip, width: 6, seed: 30 + i, taper: 2);
  }
  for (final (i, tip) in tips.indexed) {
    for (var pair = 0; pair < pairs; pair++) {
      // From the soil up the stem; the topmost pair is the smallest.
      final at = Offset.lerp(base, tip, 0.3 + 0.7 * pair / pairs)!;
      final shrink = 1 - 0.15 * pair / pairs;
      for (final side in [-1, 1]) {
        await leaf(sheet, at,
            side: side,
            angle: 0.35 + 0.1 * pair,
            length: size * shrink,
            width: size * 0.8 * shrink,
            seed: 200 + i * 20 + pair * 2 + (side + 1) ~/ 2,
            round: true);
      }
    }
    if (stage == GrowthStage.mature) {
      for (var f = 0; f < 3; f++) {
        await bud(sheet, tip + Offset(0, -6.0 - f * 9),
            rx: 6 - f * 1.2, ry: 6, seed: 300 + i * 5 + f);
      }
    }
  }
}

/// REQ-015's **bush** (35–49 minutes): dense, leafy, medium height. A dome of
/// overlapping clumps, and flower heads scattered over it when it is grown.
Future<void> paintBush(Sheet sheet, GrowthStage stage) async {
  await soil(sheet, stage);
  if (stage == GrowthStage.seed) return;

  if (stage == GrowthStage.sprout) {
    await stalk(sheet, const Offset(256, 500), const Offset(256, 466),
        width: 5, seed: 21);
    await leaf(sheet, const Offset(256, 468),
        side: -1, angle: 0.5, length: 22, width: 14, seed: 101);
    await leaf(sheet, const Offset(256, 468),
        side: 1, angle: 0.6, length: 21, width: 14, seed: 102);
    return;
  }

  // (x, y, rx, ry) of each clump at full size, back row first. Earlier stages
  // draw the first few, smaller and lower.
  const clumps = [
    (256.0, 300.0, 62.0, 52.0),
    (196.0, 340.0, 52.0, 46.0),
    (316.0, 340.0, 52.0, 46.0),
    (226.0, 270.0, 46.0, 40.0),
    (288.0, 266.0, 46.0, 40.0),
    (192.0, 410.0, 48.0, 42.0),
    (320.0, 410.0, 48.0, 42.0),
    (256.0, 380.0, 64.0, 56.0),
    (256.0, 440.0, 58.0, 44.0),
  ];
  final (count, scale) = switch (stage) {
    GrowthStage.young => (4, 0.5),
    GrowthStage.maturing => (7, 0.75),
    _ => (9, 1.0),
  };

  // Shrink toward the soil, so a young bush is a low clump, not a floating one.
  Offset placed(double x, double y) =>
      Offset(256 + (x - 256) * scale, 500 - (500 - y) * scale);

  await stalk(sheet, const Offset(256, 500), placed(256, 400),
      width: 10 * scale + 4, seed: 21, role: Role.soil, depth: 0.3);

  // The order the clumps are revealed in: the ones nearest the soil first.
  const order = [8, 7, 5, 6, 1, 2, 0, 3, 4];
  final shown = [for (final i in order.take(count)) i]..sort();
  for (final i in shown) {
    final (x, y, rx, ry) = clumps[i];
    await clump(sheet, placed(x, y),
        rx: rx * scale, ry: ry * scale, seed: 500 + i, lobes: 9);
  }

  if (stage != GrowthStage.mature) return;
  final random = math.Random(560);
  for (var i = 0; i < 8; i++) {
    final angle = math.pi * (1.1 + 0.8 * i / 7);
    final reach = 60 + random.nextDouble() * 40;
    await blossom(
      sheet,
      Offset(256 + math.cos(angle) * reach * 1.15, 360 + math.sin(angle) * reach),
      radius: 11,
      seed: 600 + i * 10,
      petals: 6,
      turn: random.nextDouble(),
    );
  }
}

/// REQ-015's **small tree** (50–74 minutes): cherry blossom, maple. A slim
/// trunk that forks into a rounded crown, scattered with blossom when grown.
Future<void> paintSmallTree(Sheet sheet, GrowthStage stage) =>
    _tree(sheet, stage, _smallTree);

/// REQ-015's **large tree** (75–120 minutes): oak, willow, pine. A heavy
/// trunk and a crown that fills the sheet: the grand feature of a garden.
Future<void> paintLargeTree(Sheet sheet, GrowthStage stage) =>
    _tree(sheet, stage, _largeTree);

/// REQ-021's **bonus plant**, one drawing for all seven milestone species: a
/// tree hung with long tassels of blossom, unlike anything a session grows.
Future<void> paintBonus(Sheet sheet, GrowthStage stage) =>
    _tree(sheet, stage, _bonusTree);

/// The shape of a tree at full size, which earlier stages draw smaller.
final class _TreePlan {
  const _TreePlan({
    required this.trunkTop,
    required this.trunkWidth,
    required this.branches,
    required this.crown,
    required this.flowers,
    this.tassels = 0,
  });

  final Offset trunkTop;
  final double trunkWidth;

  /// Where each branch reaches from the trunk.
  final List<Offset> branches;

  /// (x, y, rx, ry) of each clump of the crown, back first.
  final List<(double, double, double, double)> crown;

  /// How many blossoms the grown tree carries.
  final int flowers;

  /// How many hanging tassels of blossom, for the bonus tree.
  final int tassels;
}

const _smallTree = _TreePlan(
  trunkTop: Offset(258, 250),
  trunkWidth: 20,
  branches: [Offset(196, 200), Offset(322, 196), Offset(250, 150)],
  crown: [
    (256, 140, 78, 62),
    (178, 190, 70, 58),
    (334, 186, 70, 58),
    (210, 120, 62, 50),
    (304, 118, 62, 50),
    (256, 210, 84, 62),
  ],
  flowers: 14,
);

const _largeTree = _TreePlan(
  trunkTop: Offset(256, 230),
  trunkWidth: 38,
  branches: [Offset(170, 210), Offset(344, 200), Offset(220, 130), Offset(300, 120)],
  crown: [
    (256, 80, 110, 80),
    (150, 150, 92, 76),
    (362, 146, 92, 76),
    (190, 70, 80, 64),
    (322, 66, 80, 64),
    (120, 230, 76, 60),
    (392, 226, 76, 60),
    (256, 190, 118, 84),
    (256, 250, 96, 58),
  ],
  flowers: 0,
);

const _bonusTree = _TreePlan(
  trunkTop: Offset(256, 220),
  trunkWidth: 34,
  branches: [Offset(160, 190), Offset(352, 186), Offset(256, 110)],
  crown: [
    (256, 90, 120, 84),
    (146, 160, 96, 74),
    (366, 156, 96, 74),
    (200, 70, 84, 62),
    (312, 66, 84, 62),
    (256, 196, 122, 76),
  ],
  flowers: 6,
  tassels: 7,
);

Future<void> _tree(Sheet sheet, GrowthStage stage, _TreePlan plan) async {
  await soil(sheet, stage);
  if (stage == GrowthStage.seed) return;

  const ground = Offset(256, 500);
  if (stage == GrowthStage.sprout) {
    await stalk(sheet, ground, const Offset(256, 440),
        width: 6, seed: 21, role: Role.soil, depth: 0.3);
    await leaf(sheet, const Offset(256, 444),
        side: -1, angle: 0.55, length: 24, width: 15, seed: 101);
    await leaf(sheet, const Offset(256, 444),
        side: 1, angle: 0.65, length: 23, width: 15, seed: 102);
    await leaf(sheet, const Offset(256, 442),
        side: 1, angle: 1.4, length: 16, width: 11, seed: 103);
    return;
  }

  // Young is a sapling, maturing a half-grown tree, mature the whole plan.
  final scale = switch (stage) {
    GrowthStage.young => 0.42,
    GrowthStage.maturing => 0.72,
    _ => 1.0,
  };
  Offset placed(Offset p) =>
      Offset(256 + (p.dx - 256) * scale, 500 - (500 - p.dy) * scale);

  final trunkTop = placed(plan.trunkTop);
  await stalk(sheet, ground, trunkTop,
      width: plan.trunkWidth * scale + 3,
      taper: plan.trunkWidth * scale * 0.4,
      seed: 21,
      role: Role.soil,
      depth: 0.3);

  // A sapling has a couple of branches; a grown tree has them all.
  final branches = stage == GrowthStage.young
      ? plan.branches.take(1).toList()
      : plan.branches;
  for (final (i, end) in branches.indexed) {
    await stalk(sheet, Offset.lerp(ground, trunkTop, 0.85)!, placed(end),
        width: plan.trunkWidth * scale * 0.45 + 2,
        taper: plan.trunkWidth * scale * 0.3,
        seed: 40 + i,
        role: Role.soil,
        depth: 0.3,
        bend: i.isEven ? 0.08 : -0.08);
  }

  final clumps = switch (stage) {
    GrowthStage.young => plan.crown.take(3).toList(),
    GrowthStage.maturing => plan.crown.take(plan.crown.length - 1).toList(),
    _ => plan.crown,
  };
  for (final (i, (x, y, rx, ry)) in clumps.indexed) {
    await clump(sheet, placed(Offset(x, y)),
        rx: rx * scale, ry: ry * scale, seed: 500 + i, lobes: 11);
  }

  if (stage != GrowthStage.mature) return;

  final random = math.Random(700);
  // Wisteria's hanging racemes: each a chain of overlapping round florets,
  // largest at the top and shrinking toward the tip.
  for (var i = 0; i < plan.tassels; i++) {
    final x = 140 + 232 * i / (plan.tassels - 1) +
        (random.nextDouble() - 0.5) * 12;
    final top = 196 + random.nextDouble() * 30;
    final drift = (random.nextDouble() - 0.5) * 8;
    const florets = 6;
    for (var f = 0; f < florets; f++) {
      final t = f / (florets - 1);
      final r = 13 - 7 * t;
      await bud(sheet, Offset(x + drift * t, top + f * 13),
          rx: r, ry: r * 0.9, seed: 720 + i * 10 + f);
    }
  }
  for (var i = 0; i < plan.flowers; i++) {
    final (x, y, rx, ry) = plan.crown[i % plan.crown.length];
    final angle = random.nextDouble() * 2 * math.pi;
    final r = 0.55 * random.nextDouble();
    await blossom(
      sheet,
      Offset(x + math.cos(angle) * rx * r, y + math.sin(angle) * ry * r),
      radius: 10,
      seed: 800 + i * 10,
      turn: random.nextDouble(),
    );
  }
}

/// PRD §5.1's app icon: a single seedling in soil, filling its square, cut
/// from paper like everything in the garden. Bolder than the sprout sprite,
/// because it has to read at 20 points.
Future<void> paintIconSeedling(Sheet sheet) async {
  final s = scaleOf(sheet);
  await sheet.wash(
    wobbly(
      [for (final p in mound(const Offset(256, 420), 200, 96)) p * s],
      seed: 11,
      amplitude: wobbleOf(sheet, 2),
    ),
    role: Role.soil,
    seed: 11,
    depth: 0.14,
    rim: 0.45,
    shade: (x, y) => y * 512 > 380 ? 0.1 : 0,
  );
  await stalk(sheet, const Offset(256, 370), const Offset(258, 170),
      width: 26, taper: 6, seed: 21);
  await leaf(sheet, const Offset(256, 190),
      side: -1, angle: 0.45, length: 150, width: 96, seed: 101);
  await leaf(sheet, const Offset(258, 184),
      side: 1, angle: 0.6, length: 140, width: 90, seed: 102);
}
