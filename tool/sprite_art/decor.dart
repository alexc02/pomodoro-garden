import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'parts.dart';
import 'wash.dart';

/// REQ-040's four objects, cut from paper like the plants.
///
/// A decor sprite's mask carries different roles from a plant's
/// (`docs/art-pipeline.md`), so the three [Role]s are spent differently here:
///
/// | Role | For an object |
/// |---|---|
/// | [material] (the foliage channel) | what it is made of: stone, timber |
/// | [water] (the bloom channel) | a pond's or a birdbath's water, a lantern's light |
/// | [shade] (the soil channel) | the shadow it casts on the ground it stands on |
const Role material = Role.foliage;
const Role water = Role.bloom;
const Role shade = Role.soil;

/// Paints [kind] onto [sheet].
Future<void> paintDecor(Sheet sheet, DecorKind kind) => switch (kind) {
      DecorKind.lantern => _lantern(sheet),
      DecorKind.bench => _bench(sheet),
      DecorKind.birdbath => _birdbath(sheet),
      DecorKind.pond => _pond(sheet),
    };

/// One flat paper piece: [outline] on the 512 grid, cut in [role].
Future<void> _piece(
  Sheet sheet,
  List<Offset> outline, {
  required Role role,
  required int seed,
  double depth = 0.1,
  double wobble = 1.0,
  double Function(double x, double y)? shading,
}) {
  final s = scaleOf(sheet);
  return sheet.wash(
    wobbly([for (final p in outline) p * s],
        seed: seed, amplitude: wobbleOf(sheet, wobble)),
    role: role,
    seed: seed,
    depth: depth,
    rim: 0.4,
    shade: shading,
  );
}

/// A rectangle from [left], [top] to [right], [bottom] on the 512 grid.
List<Offset> _box(double left, double top, double right, double bottom) => [
      Offset(left, top),
      Offset(right, top),
      Offset(right, bottom),
      Offset(left, bottom),
    ];

/// The shadow an object casts on the ground: a flat ellipse under it, carried
/// to the bottom edge so the object stands on its plot.
Future<void> _shadow(Sheet sheet, double rx, double ry, {required int seed}) =>
    _piece(
      sheet,
      ellipse(Offset(256, 512 - ry + 4), rx, ry),
      role: shade,
      seed: seed,
      depth: 0.3,
    );

/// A darker right-hand half, as the side of a stone away from the light.
double Function(double, double) _sideLit(double middle) =>
    (x, y) => x * 512 > middle ? 0.1 : 0;

Future<void> _lantern(Sheet sheet) async {
  await _shadow(sheet, 86, 22, seed: 900);
  // Base, post, firebox, roof and finial, bottom to top.
  await _piece(sheet, _box(196, 470, 316, 508),
      role: material, seed: 901, shading: _sideLit(256));
  await _piece(sheet, _box(230, 380, 282, 472),
      role: material, seed: 902, shading: _sideLit(256));
  await _piece(sheet, _box(204, 360, 308, 384),
      role: material, seed: 903, shading: _sideLit(256));
  await _piece(sheet, _box(214, 300, 298, 362),
      role: material, seed: 904, shading: _sideLit(256));
  // The window, lit.
  await _piece(sheet, _box(234, 314, 278, 350),
      role: water, seed: 905, depth: 0.04, wobble: 0.5);
  await _piece(
    sheet,
    const [
      Offset(176, 304),
      Offset(214, 284),
      Offset(256, 270),
      Offset(298, 284),
      Offset(336, 304),
      Offset(300, 300),
      Offset(212, 300),
    ],
    role: material,
    seed: 906,
    shading: _sideLit(256),
  );
  await _piece(sheet, ellipse(const Offset(256, 268), 12, 12),
      role: material, seed: 907);
}

Future<void> _bench(Sheet sheet) async {
  await _shadow(sheet, 160, 24, seed: 910);
  // Two legs, the seat, and the back on two posts.
  await _piece(sheet, _box(130, 430, 154, 506), role: material, seed: 911);
  await _piece(sheet, _box(358, 430, 382, 506), role: material, seed: 912);
  await _piece(sheet, _box(130, 352, 148, 430), role: material, seed: 913);
  await _piece(sheet, _box(364, 352, 382, 430), role: material, seed: 914);
  await _piece(sheet, _box(112, 356, 400, 382),
      role: material, seed: 915, shading: (x, y) => y * 512 > 371 ? 0.1 : 0);
  await _piece(sheet, _box(100, 418, 412, 444),
      role: material, seed: 916, shading: (x, y) => y * 512 > 433 ? 0.1 : 0);
}

Future<void> _birdbath(Sheet sheet) async {
  await _shadow(sheet, 92, 22, seed: 920);
  // Foot, pedestal, bowl, and the water in it.
  await _piece(sheet, _box(212, 476, 300, 508),
      role: material, seed: 921, shading: _sideLit(256));
  await _piece(
    sheet,
    const [
      Offset(236, 476),
      Offset(242, 350),
      Offset(270, 350),
      Offset(276, 476),
    ],
    role: material,
    seed: 922,
    shading: _sideLit(256),
  );
  await _piece(
    sheet,
    [
      ...ellipse(const Offset(256, 312), 102, 22).take(37),
      const Offset(200, 352),
      const Offset(312, 352),
    ],
    role: material,
    seed: 923,
    shading: _sideLit(256),
  );
  await _piece(sheet, ellipse(const Offset(256, 308), 88, 16),
      role: water, seed: 924, depth: 0.06, wobble: 0.6);
}

Future<void> _pond(Sheet sheet) async {
  // The ground the pond is set into, then its stone rim, then the water.
  await _piece(sheet, ellipse(const Offset(256, 444), 206, 70),
      role: shade, seed: 930, depth: 0.25);
  await _piece(sheet, ellipse(const Offset(256, 436), 190, 60),
      role: material, seed: 931, shading: (x, y) => y * 512 > 456 ? 0.1 : 0);
  await _piece(sheet, ellipse(const Offset(252, 432), 160, 44),
      role: water,
      seed: 932,
      depth: 0.06,
      shading: (x, y) => y * 512 < 412 ? 0.1 : 0);
  // A few stones on the rim, and a lily pad on the water.
  for (final (i, (x, y, r)) in const [
    (90.0, 410.0, 18.0),
    (410.0, 420.0, 22.0),
    (150.0, 470.0, 16.0),
    (370.0, 474.0, 14.0),
  ].indexed) {
    await _piece(sheet, ellipse(Offset(x, y), r, r * 0.7),
        role: material, seed: 940 + i, shading: _sideLit(x));
  }
  await _piece(sheet, ellipse(const Offset(300, 426), 22, 10),
      role: material, seed: 950, depth: 0.2);
}
