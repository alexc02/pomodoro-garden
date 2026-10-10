import 'dart:math' as math;
import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'plant_sprite.dart';

/// The [PlantSpriteRegistry] the app runs on until ticket 23 delivers the
/// watercolour art: thirty plants drawn out of circles and lines.
///
/// The placeholders are deliberately crude but not interchangeable. A user
/// running a 90-minute session has to be able to see that they are growing
/// something bigger than the 15-minute session grew, and has to see it change
/// four times on the way — that is the behaviour this ticket ships, and art it
/// is not waiting on. Ticket 23 replaces this class and nothing else.
final class PlaceholderPlantSpriteRegistry implements PlantSpriteRegistry {
  const PlaceholderPlantSpriteRegistry();

  /// Built once, at first use, rather than per lookup. Ticket 07 asks this
  /// registry for a sprite per plant per frame with two hundred plants on
  /// screen; that has to be a map read, not thirty allocations.
  static final Map<(PlantType, GrowthStage), PlantSprite> _sprites = {
    for (final type in PlantType.values)
      for (final stage in GrowthStage.values)
        (type, stage): PlaceholderPlantSprite(type: type, stage: stage),
  };

  @override
  PlantSprite spriteFor({
    required PlantType type,
    required GrowthStage stage,
  }) =>
      _sprites[(type, stage)]!;
}

/// What a plant's silhouette is built from at its full size.
///
/// Presentation, not domain: the growth rules know that a 50-minute session
/// grows a small tree, and this knows that a small tree is a trunk with a
/// canopy on it.
enum _Crown {
  /// Petals around a centre — the wildflowers and the flowers.
  bloom,

  /// A soft clump of leaves — the herbs and the bushes.
  tuft,

  /// A trunk under a mass of foliage — the two trees.
  canopy,

  /// A canopy inside a ring of blooms — REQ-021's bonus plants, and the one
  /// crown no session length can grow.
  ///
  /// Its own shape rather than a canopy in a different colour, because
  /// "visually distinct" has to survive a colour-blind user and a garden seen
  /// from a long way out. A bonus plant is the tallest thing in the garden and
  /// the only one with a halo, so it reads as special by silhouette alone.
  aura,
}

/// One plant's measurements inside the box it is drawn in.
///
/// Everything is measured from [base], the point on the ground the plant
/// stands on, because that is the one thing about a plant's position that does
/// not depend on how big it has grown.
final class _Anatomy {
  const _Anatomy({
    required this.base,
    required this.extent,
    required this.spread,
    required this.crown,
    required this.stemWidth,
    required this.reach,
  });

  /// The middle of the bottom edge of the box: where the plant meets the soil.
  final Offset base;

  /// How far above [base] the highest part of the plant reaches.
  final double extent;

  /// The half-width the crown and the leaves are sized against.
  final double spread;

  /// The crown's size, how far it reaches above the point it hangs from, and
  /// how far it reaches to either side of it.
  final ({double radius, double rise, double reach}) crown;

  /// How thick the stem or trunk is drawn.
  final double stemWidth;

  /// How far to either side of [base] the widest part of the plant gets.
  final double reach;

  /// Where the crown hangs from: the top of the stem.
  Offset get top => base.translate(0, -(extent - crown.rise));
}

/// One placeholder plant: a [PlantType] at a [GrowthStage], drawn from shapes.
final class PlaceholderPlantSprite implements PlantSprite {
  const PlaceholderPlantSprite({required this.type, required this.stage});

  final PlantType type;
  final GrowthStage stage;

  @override
  void paint(Canvas canvas, Rect bounds, PlantPalette palette) {
    if (bounds.isEmpty) return;

    final plant = _anatomyIn(bounds);

    if (stage == GrowthStage.seed) {
      // REQ-016: a small dot in the soil. Not scaled by type — every plant
      // starts as the same seed, and the first thing that distinguishes a
      // ninety-minute session from a fifteen-minute one is how fast it leaves
      // this behind.
      final radius = plant.extent / 2;
      canvas.drawCircle(
        plant.base.translate(0, -radius),
        radius,
        Paint()..color = palette.soil,
      );
      return;
    }

    final top = plant.top;
    _paintStem(canvas, plant.base, top, plant.stemWidth, palette);
    _paintLeaves(
      canvas,
      plant.base,
      plant.base.dy - top.dy,
      plant.spread,
      palette,
    );
    _paintCrown(canvas, top, plant.crown, palette);
  }

  @override
  Rect footprintIn(Rect bounds) {
    if (bounds.isEmpty) return Rect.zero;

    final plant = _anatomyIn(bounds);
    // Half a stroke past each end of the stem, because its cap is round: the
    // drawing reaches a hair below the soil it stands on and, before there is
    // a crown to hide it, a hair above the top of the stem.
    final cap = plant.stemWidth / 2;

    return Rect.fromLTRB(
      plant.base.dx - plant.reach,
      plant.base.dy - plant.extent - cap,
      plant.base.dx + plant.reach,
      plant.base.dy + cap,
    );
  }

  /// Where every part of this plant sits inside [bounds].
  ///
  /// Worked out once and used twice — [paint] draws from it, [footprintIn]
  /// measures it — because the two must not disagree. A footprint derived
  /// separately from the drawing is one that drifts away from it as the
  /// drawing is tuned, and what it decides is which plant a finger landed on.
  _Anatomy _anatomyIn(Rect bounds) {
    final base = Offset(bounds.center.dx, bounds.bottom);

    if (stage == GrowthStage.seed) {
      final radius = math.min(bounds.width, bounds.height) * 0.04;
      return _Anatomy(
        base: base,
        extent: radius * 2,
        spread: 0,
        crown: (radius: 0, rise: 0, reach: 0),
        stemWidth: 0,
        reach: radius,
      );
    }

    // How far above the soil the highest part of the plant reaches. Everything
    // else is measured back from it, so a plant always fills exactly as much of
    // its box as its type and stage say it should — a crown that grew out of
    // the top of the box would make a large tree at 80% look the same size as
    // one at 100%.
    final extent = bounds.height * _fullHeight * _stageHeight;
    // Never wider than the box it was given, however tall the plant is.
    final spread = math.min(extent * 0.28, bounds.width * 0.45);
    final crown = _crownGeometry(spread);
    final stemWidth = math.max(1.5, extent * (_isWoody ? 0.1 : 0.05));

    return _Anatomy(
      base: base,
      extent: extent,
      spread: spread,
      crown: crown,
      stemWidth: stemWidth,
      reach: math.max(
        stemWidth / 2,
        math.max(_leafReach(spread), crown.reach),
      ),
    );
  }

  /// How far to either side of the stem the leaves get. Zero for a tree, whose
  /// leaves are all in its canopy, and for a plant that has none yet.
  ///
  /// A leaf is an oval [_leafLength] across, hung from the stem by half its own
  /// length, so it reaches its whole length out — the same number
  /// [_paintLeaves] draws it at.
  double _leafReach(double spread) =>
      _isWoody || _leafPairs == 0 ? 0 : spread * _leafLength;

  /// How much of its box this type fills when fully grown. REQ-015's visual
  /// column, as numbers: a wildflower is small and a large tree dominates.
  double get _fullHeight => switch (type) {
        PlantType.wildflower => 0.45,
        PlantType.herb => 0.55,
        PlantType.flower => 0.75,
        PlantType.bush => 0.6,
        PlantType.smallTree => 0.85,
        PlantType.largeTree => 1,
        // REQ-021: the same height as the largest thing a session can grow, and
        // then wider than it, because the halo reaches further than any canopy.
        // A bonus plant that was merely another large tree would be the reward
        // for a hundred sessions that nobody could pick out of the garden.
        PlantType.bonus => 1,
      };

  /// How much of its full height the plant has reached at this stage.
  ///
  /// Not linear in progress: the visible jump from sprout to young is the one
  /// that reads as growth at a glance, and the last two stages are about the
  /// crown filling in rather than the plant getting taller.
  double get _stageHeight => switch (stage) {
        GrowthStage.seed => 0,
        GrowthStage.sprout => 0.25,
        GrowthStage.young => 0.6,
        GrowthStage.maturing => 0.88,
        GrowthStage.mature => 1,
      };

  _Crown get _crown => switch (type) {
        PlantType.wildflower || PlantType.flower => _Crown.bloom,
        PlantType.herb || PlantType.bush => _Crown.tuft,
        PlantType.smallTree || PlantType.largeTree => _Crown.canopy,
        PlantType.bonus => _Crown.aura,
      };

  /// Whether this plant stands on a trunk rather than a stem.
  ///
  /// Three things follow from it and they have to follow together: the stem is
  /// drawn thicker, it is drawn in the soil colour because wood is not green,
  /// and no leaves run up it because a tree's leaves are all in its crown.
  bool get _isWoody => _crown == _Crown.canopy || _crown == _Crown.aura;

  /// How many pairs of leaves run up the stem. A sprout has one pair; a grown
  /// plant has as many as it will get.
  int get _leafPairs => switch (stage) {
        GrowthStage.seed => 0,
        GrowthStage.sprout => 1,
        GrowthStage.young => 2,
        _ => 3,
      };

  /// How the crown is put together, as fractions of its own radius.
  ///
  /// Named rather than written into the drawing, because [_crownGeometry]
  /// measures the crown out of the same numbers [_paintCrown] draws it from. A
  /// petal moved by hand in one place and not the other is a plant whose
  /// footprint quietly stops matching its picture, and nothing draws the
  /// footprint, so nobody would see it.

  /// How far out from the middle an open bloom's petals sit.
  static const double _petalOffset = 0.9;

  /// A closed bud's oval, across and up.
  static const double _budWidth = 0.5;
  static const double _budHeight = 0.85;

  /// A clump's three circles: two set this far out to the sides…
  static const double _clumpSpread = 0.55;

  /// …at this much of the radius each…
  static const double _clumpSide = 0.8;

  /// …and one full-sized circle lifted this far above the middle.
  static const double _clumpTop = 0.45;

  /// A leaf's length, as a fraction of the spread.
  static const double _leafLength = 0.6;

  /// How far out from the middle of the crown an aura's blooms are set…
  static const double _auraOffset = 1.15;

  /// …and how big each of them is, both as fractions of the crown's radius.
  static const double _auraPetal = 0.3;

  /// How many blooms make up the halo. Enough to read as a ring rather than as
  /// a handful of dots, few enough that they do not merge into a solid disc.
  static const int _auraBlooms = 7;

  /// The size of the crown, how far it reaches above the point it is hung from,
  /// and how far it reaches to either side.
  ///
  /// All three come out of one place because they have to agree: [paint]
  /// positions the stem by subtracting the rise, so a crown that reached higher
  /// than it said would push the plant out of its box, and [footprintIn] takes
  /// the reach, so a crown that reached wider than it said would be a canopy
  /// the user could not tap the edge of.
  ({double radius, double rise, double reach}) _crownGeometry(double spread) {
    // Nothing has a crown before it is nearly grown: REQ-016's young stage is
    // "a recognisable plant shape", not a flowering one.
    if (stage != GrowthStage.maturing && stage != GrowthStage.mature) {
      return (radius: 0, rise: 0, reach: 0);
    }

    final isOpen = stage == GrowthStage.mature;

    return switch (_crown) {
      // An open bloom is petals set out around a middle, so it reaches exactly
      // as far up as it does sideways; a closed bud is an oval on the stem.
      _Crown.bloom when isOpen => _bloom(spread * 0.42),
      _Crown.bloom => _bud(spread * 0.5),
      _Crown.tuft => _clump(spread * (isOpen ? 0.75 : 0.55)),
      _Crown.canopy => _clump(spread * (isOpen ? 1 : 0.7)),
      // The halo only appears once the plant has opened. Before that a bonus
      // plant is a canopy like any other, which is what makes the award's last
      // stage the one that reads as an award.
      _Crown.aura when isOpen => _aura(spread),
      _Crown.aura => _clump(spread * 0.7),
    };
  }

  static ({double radius, double rise, double reach}) _bloom(double radius) {
    final petal = radius * (_petalOffset + 1);
    return (radius: radius, rise: petal, reach: petal);
  }

  static ({double radius, double rise, double reach}) _bud(double radius) => (
        radius: radius,
        rise: radius * _budHeight / 2,
        reach: radius * _budWidth / 2,
      );

  static ({double radius, double rise, double reach}) _clump(double radius) => (
        radius: radius,
        rise: radius * (1 + _clumpTop),
        reach: radius * (_clumpSpread + _clumpSide),
      );

  /// A clump with a ring of blooms set outside it.
  ///
  /// The halo reaches further than the clump does in both directions, so the
  /// maximum is taken rather than assumed: [paint] positions the stem by
  /// subtracting the rise, and [footprintIn] takes the reach, so a halo that
  /// reached further than it said would hang out of its own box and be a plant
  /// the user could not tap the edge of.
  static ({double radius, double rise, double reach}) _aura(double radius) {
    final clump = _clump(radius);
    final halo = radius * (_auraOffset + _auraPetal);

    return (
      radius: radius,
      rise: math.max(clump.rise, halo),
      reach: math.max(clump.reach, halo),
    );
  }

  void _paintStem(
    Canvas canvas,
    Offset base,
    Offset top,
    double stemWidth,
    PlantPalette palette,
  ) {
    canvas.drawLine(
      base,
      top,
      Paint()
        // A trunk is wood and reads as soil; a stem is green.
        ..color = _isWoody ? palette.soil : palette.foliage
        ..strokeWidth = stemWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintLeaves(
    Canvas canvas,
    Offset base,
    double stemLength,
    double spread,
    PlantPalette palette,
  ) {
    // A tree's leaves are in its canopy, not up its trunk.
    if (_isWoody) return;

    final paint = Paint()..color = palette.foliage;
    final leaf = Size(spread * _leafLength, spread * 0.32);

    for (var pair = 0; pair < _leafPairs; pair++) {
      final up = stemLength * (0.3 + pair * 0.22);
      for (final side in const [-1.0, 1.0]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: base.translate(side * leaf.width * 0.5, -up),
            width: leaf.width,
            height: leaf.height,
          ),
          paint,
        );
      }
    }
  }

  void _paintCrown(
    Canvas canvas,
    Offset top,
    ({double radius, double rise, double reach}) crown,
    PlantPalette palette,
  ) {
    if (crown.radius == 0) return;

    final isOpen = stage == GrowthStage.mature;

    switch (_crown) {
      case _Crown.bloom:
        if (isOpen) {
          // Five petals around a centre. The bloom colour is spent here and
          // nowhere else on the plant — a flower that has opened is the reward.
          final petals = Paint()..color = palette.bloom;
          for (var i = 0; i < 5; i++) {
            final angle = i * 2 * math.pi / 5 - math.pi / 2;
            canvas.drawCircle(
              top +
                  Offset(math.cos(angle), math.sin(angle)) *
                      crown.radius *
                      _petalOffset,
              crown.radius,
              petals,
            );
          }
          canvas.drawCircle(
            top,
            crown.radius * 0.55,
            Paint()..color = palette.soil,
          );
        } else {
          // Pre-bloom: a closed green bud, so the flower opening at 100% is a
          // change the user actually sees.
          canvas.drawOval(
            Rect.fromCenter(
              center: top,
              width: crown.radius * _budWidth,
              height: crown.radius * _budHeight,
            ),
            Paint()..color = palette.foliage,
          );
        }
      case _Crown.tuft:
        _paintClump(canvas, top, crown.radius, palette);
        if (isOpen) {
          // A grown herb or bush carries a little colour, but far less than a
          // flower: the reward tiers are meant to read at a glance.
          canvas.drawCircle(
            top.translate(0, -crown.radius * 0.2),
            crown.radius * 0.27,
            Paint()..color = palette.bloom,
          );
        }
      case _Crown.canopy:
        _paintClump(canvas, top, crown.radius, palette);
      case _Crown.aura:
        _paintClump(canvas, top, crown.radius, palette);
        if (!isOpen) return;
        // REQ-021's award, and the only plant in the garden that spends the
        // bloom colour on more than a flower: a ring of blooms standing off the
        // canopy. Drawn after the clump so the halo sits in front of it.
        final blooms = Paint()..color = palette.bloom;
        for (var i = 0; i < _auraBlooms; i++) {
          final angle = i * 2 * math.pi / _auraBlooms - math.pi / 2;
          canvas.drawCircle(
            top +
                Offset(math.cos(angle), math.sin(angle)) *
                    crown.radius *
                    _auraOffset,
            crown.radius * _auraPetal,
            blooms,
          );
        }
    }
  }

  /// Three overlapping circles: the cheapest shape that reads as a mass of
  /// leaves rather than as a ball.
  void _paintClump(
    Canvas canvas,
    Offset top,
    double radius,
    PlantPalette palette,
  ) {
    final paint = Paint()..color = palette.foliage;
    canvas.drawCircle(
      top.translate(-radius * _clumpSpread, 0),
      radius * _clumpSide,
      paint,
    );
    canvas.drawCircle(
      top.translate(radius * _clumpSpread, 0),
      radius * _clumpSide,
      paint,
    );
    canvas.drawCircle(top.translate(0, -radius * _clumpTop), radius, paint);
  }
}
