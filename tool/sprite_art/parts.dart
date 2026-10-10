import 'dart:math' as math;
import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'wash.dart';

/// The pieces every plant is cut from, so the six types and the bonus plant
/// are one hand rather than seven.
///
/// Every function takes coordinates on a 512-pixel sheet and scales them to
/// the sheet it is given, and takes a seed so the same piece is cut the same
/// way at every stage it appears in. A plant that keeps its seeds from stage to
/// stage reads as one plant growing (`art_delivery_test.dart`).

/// The middle of the sheet's bottom edge, where every plant stands.
Offset groundOf(Sheet sheet) => Offset(sheet.side / 2, sheet.side.toDouble());

/// The scale from the 512-pixel design grid to [sheet].
double scaleOf(Sheet sheet) => sheet.side / 512;

/// How far an outline wanders on [sheet], for a shape that asks for [amount]
/// at 512 pixels.
double wobbleOf(Sheet sheet, double amount) =>
    amount * scaleOf(sheet) * sheet.finish.wobble;

/// The soil every plant stands in, the same at every stage so a plant is never
/// narrower than the ground it came out of — and at the seed stage, the seed.
Future<void> soil(Sheet sheet, GrowthStage stage) async {
  final s = scaleOf(sheet);
  final ground = groundOf(sheet);

  await sheet.wash(
    wobbly(mound(ground, 34 * s, 20 * s), seed: 11, amplitude: wobbleOf(sheet, 1.2)),
    role: Role.soil,
    seed: 11,
    depth: 0.14,
    rim: 0.45,
  );

  if (stage != GrowthStage.seed) return;

  await sheet.wash(
    wobbly(
      ellipse(ground + Offset(1 * s, -12 * s), 8 * s, 6 * s, angle: -0.3),
      seed: 12,
      amplitude: wobbleOf(sheet, 0.8),
    ),
    role: Role.soil,
    seed: 12,
    depth: 0.47,
    rim: 0.35,
  );
}

/// A stem or a trunk from [from] to [to], [width] thick at its foot and
/// tapering by [taper] to its tip.
Future<void> stalk(
  Sheet sheet,
  Offset from,
  Offset to, {
  required double width,
  required int seed,
  double taper = 2.5,
  double bend = 0.025,
  Role role = Role.foliage,
  double depth = 0.24,
}) async {
  final s = scaleOf(sheet);
  await sheet.wash(
    wobbly(
      along(from * s, to * s, width: (t) => (width - taper * t) * s, bend: bend),
      seed: seed,
      amplitude: wobbleOf(sheet, 0.7),
    ),
    role: role,
    seed: seed,
    depth: depth,
    rim: 0.3,
  );
}

/// A leaf growing from [from], [angle] radians above horizontal on [side]
/// (−1 left, 1 right), with a darker half and a midrib.
///
/// [round] makes it broader, for the oval leaves of a herb.
Future<void> leaf(
  Sheet sheet,
  Offset from, {
  required int side,
  required double angle,
  required double length,
  required double width,
  required int seed,
  bool round = false,
  bool rib = true,
}) async {
  final s = scaleOf(sheet);
  final start = from * s;
  final end = start +
      Offset(
        side * math.cos(angle) * length * s,
        -math.sin(angle) * length * s,
      );
  // Leaves droop at the tip: the bow is away from the sky on both sides.
  final bend = -0.14 * side;

  await sheet.wash(
    wobbly(
      along(
        start,
        end,
        width: round ? ovalProfile(width * s) : leafProfile(width * s),
        bend: bend,
      ),
      seed: seed,
      amplitude: wobbleOf(sheet, 2.2),
    ),
    role: Role.foliage,
    seed: seed,
    depth: 0.08,
    rim: 0.6,
    // Darker toward the stalk, and on one side of the midrib: a second layer
    // laid over half of it.
    shade: (x, y) {
      final p = Offset(x, y) * sheet.side.toDouble();
      final near = 1 - ((p - start).distance / (length * s)).clamp(0, 1);
      final axis = end - start;
      final offAxis = p - start;
      final lower = axis.dx * offAxis.dy - axis.dy * offAxis.dx;
      final shadowed = lower * side > 0 ? 0.13 : 0.0;
      return 0.14 * near * near + shadowed;
    },
  );

  if (!rib) return;
  final tip = Offset.lerp(start, end, 0.82)!;
  await sheet.wash(
    wobbly(
      along(start, tip, width: (t) => 2.4 * s * (1 - 0.8 * t), bend: bend),
      seed: seed + 1000,
      amplitude: wobbleOf(sheet, 0.4),
    ),
    role: Role.foliage,
    seed: seed + 1000,
    depth: 0.26,
    rim: 0.1,
    mottle: 0.05,
  );
}

/// The width profile of a rounded leaf: an oval, broadest at the middle.
double Function(double) ovalProfile(double width) =>
    (t) => width * math.pow(math.sin(math.pi * t), 0.55);

/// A clump of foliage cut with a scalloped edge: the crown of a bush or a
/// tree. The lower part is a second, darker layer, as the shade under a crown.
Future<void> clump(
  Sheet sheet,
  Offset centre, {
  required double rx,
  required double ry,
  required int seed,
  int lobes = 9,
  double depth = 0.08,
  Role role = Role.foliage,
}) async {
  final s = scaleOf(sheet);
  final c = centre * s;
  await sheet.wash(
    wobbly(
      scallop(c, rx * s, ry * s, lobes: lobes, seed: seed),
      seed: seed,
      amplitude: wobbleOf(sheet, 1.4),
    ),
    role: role,
    seed: seed,
    depth: depth,
    rim: 0.5,
    shade: (x, y) {
      final p = Offset(x, y) * sheet.side.toDouble();
      return p.dy > c.dy + ry * s * 0.35 ? 0.12 : 0.0;
    },
  );
}

/// An ellipse whose edge bulges into [lobes] rounded scallops: a leafy outline
/// rather than a smooth one. The lobes are turned by [seed] so no two clumps
/// match.
List<Offset> scallop(
  Offset centre,
  double rx,
  double ry, {
  required int lobes,
  required int seed,
}) {
  const steps = 120;
  final turn = math.Random(seed).nextDouble() * math.pi;
  return [
    for (var i = 0; i < steps; i++)
      () {
        final t = i / steps * 2 * math.pi;
        final bulge = 0.86 + 0.14 * math.sin(lobes * t / 2 + turn).abs();
        return centre +
            Offset(math.cos(t) * rx * bulge, math.sin(t) * ry * bulge);
      }(),
  ];
}

/// A small flower of [petals] petals around a disk, centred on [centre]:
/// a wildflower's head, or a blossom on a tree.
Future<void> blossom(
  Sheet sheet,
  Offset centre, {
  required double radius,
  required int seed,
  int petals = 5,
  double turn = 0,
}) async {
  final s = scaleOf(sheet);
  final c = centre * s;
  for (var i = 0; i < petals; i++) {
    final angle = turn + i / petals * 2 * math.pi;
    final direction = Offset(math.cos(angle), math.sin(angle));
    await sheet.wash(
      wobbly(
        along(
          c + direction * radius * 0.15 * s,
          c + direction * radius * s,
          width: petalProfile(radius * 0.85 * s),
        ),
        seed: seed + i,
        amplitude: wobbleOf(sheet, 0.8),
      ),
      role: Role.bloom,
      seed: seed + i,
      depth: 0.1,
      rim: 0.4,
    );
  }
  await sheet.wash(
    wobbly(
      ellipse(c, radius * 0.28 * s, radius * 0.28 * s),
      seed: seed + 50,
      amplitude: wobbleOf(sheet, 0.4),
    ),
    role: Role.soil,
    seed: seed + 50,
    depth: 0.4,
    rim: 0.2,
  );
}

/// A closed bud of colour, [rx] by [ry], at [centre].
Future<void> bud(
  Sheet sheet,
  Offset centre, {
  required double rx,
  required double ry,
  required int seed,
}) async {
  final s = scaleOf(sheet);
  await sheet.wash(
    wobbly(
      ellipse(centre * s, rx * s, ry * s),
      seed: seed,
      amplitude: wobbleOf(sheet, 0.6),
    ),
    role: Role.bloom,
    seed: seed,
    depth: 0.12,
    rim: 0.5,
  );
}
