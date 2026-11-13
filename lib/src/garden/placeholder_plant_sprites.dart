import 'dart:math' as math;
import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'plant_sprite.dart';

/// Fallback [PlantSpriteRegistry] for builds without art: every type and
/// stage drawn from circles and lines. Forms of one type share a drawing
/// here; telling them apart is what the real art is for.
///
/// Crude, but a longer session has to visibly grow something bigger, and each
/// stage change has to be visible.
final class PlaceholderPlantSpriteRegistry implements PlantSpriteRegistry {
  const PlaceholderPlantSpriteRegistry();

  /// Built once; this is looked up per plant per frame.
  static final Map<(PlantForm, GrowthStage), PlantSprite> _sprites = {
    for (final form in PlantForm.values)
      for (final stage in GrowthStage.values)
        (form, stage): PlaceholderPlantSprite(type: form.type, stage: stage),
  };

  @override
  PlantSprite spriteFor({
    required PlantForm form,
    required GrowthStage stage,
  }) =>
      _sprites[(form, stage)]!;
}

/// The basic silhouette of a fully grown plant.
enum _Crown {
  /// Petals around a centre: wildflowers and flowers.
  bloom,

  /// A soft clump of leaves: herbs and bushes.
  tuft,

  /// A trunk under foliage: the two trees.
  canopy,

  /// A canopy inside a ring of blooms: bonus plants only. A distinct shape,
  /// not just a colour, so it still stands out for colour-blind users and when
  /// zoomed out.
  aura,
}

/// One plant's measurements inside its box, all measured from [base].
final class _Anatomy {
  const _Anatomy({
    required this.base,
    required this.extent,
    required this.spread,
    required this.crown,
    required this.stemWidth,
    required this.reach,
  });

  /// Middle of the box's bottom edge, where the plant meets the soil.
  final Offset base;

  final double extent;

  /// Half-width the crown and leaves are sized against.
  final double spread;

  /// Crown radius, how far it rises above [top], and its sideways reach.
  final ({double radius, double rise, double reach}) crown;

  final double stemWidth;

  /// Widest extent either side of [base].
  final double reach;

  /// Top of the stem, where the crown hangs.
  Offset get top => base.translate(0, -(extent - crown.rise));
}

final class PlaceholderPlantSprite implements PlantSprite {
  const PlaceholderPlantSprite({required this.type, required this.stage});

  final PlantType type;
  final GrowthStage stage;

  @override
  void paint(Canvas canvas, Rect bounds, PlantPalette palette) {
    if (bounds.isEmpty) return;

    final plant = _anatomyIn(bounds);

    if (stage == GrowthStage.seed) {
      // Same dot for every type; types only differ in how fast they leave
      // the seed stage.
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
      // Round stem caps poke half a stroke past each end.
    final cap = plant.stemWidth / 2;

    return Rect.fromLTRB(
      plant.base.dx - plant.reach,
      plant.base.dy - plant.extent - cap,
      plant.base.dx + plant.reach,
      plant.base.dy + cap,
    );
  }

  /// Where every part sits inside [bounds]. Shared by [paint] and
  /// [footprintIn] so hit-testing can't drift from the drawing.
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

    // Everything is measured back from the top, so a plant fills exactly
    // the share of its box its type and stage say.
    final extent = bounds.height * _fullHeight * _stageHeight;
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

  /// Sideways reach of the leaves. Zero for trees (leaves are in the canopy)
  /// and for plants with no leaves yet.
  double _leafReach(double spread) =>
      _isWoody || _leafPairs == 0 ? 0 : spread * _leafLength;

  /// Share of the box this type fills when fully grown.
  double get _fullHeight => switch (type) {
        PlantType.wildflower => 0.45,
        PlantType.herb => 0.55,
        PlantType.flower => 0.75,
        PlantType.bush => 0.6,
        PlantType.smallTree => 0.85,
        PlantType.largeTree => 1,
        // As tall as a large tree, and wider thanks to the halo.
        PlantType.bonus => 1,
      };

  /// Share of full height reached at this stage. Not linear: sprout to young
  /// is the big visible jump, later stages mostly fill out the crown.
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

  /// Trunk instead of stem: drawn thicker, in the soil colour, with no leaves
  /// up it.
  bool get _isWoody => _crown == _Crown.canopy || _crown == _Crown.aura;

  /// Leaf pairs up the stem.
  int get _leafPairs => switch (stage) {
        GrowthStage.seed => 0,
        GrowthStage.sprout => 1,
        GrowthStage.young => 2,
        _ => 3,
      };

  // Crown proportions, as fractions of the crown radius. Shared by
  // [_crownGeometry] and [_paintCrown] so the footprint matches the drawing.

  /// How far out from the middle an open bloom's petals sit.
  static const double _petalOffset = 0.9;

  /// Closed bud oval, width and height.
  static const double _budWidth = 0.5;
  static const double _budHeight = 0.85;

  /// Clump: two side circles this far out,
  static const double _clumpSpread = 0.55;

  /// this big,
  static const double _clumpSide = 0.8;

  /// and one full-size circle raised this far.
  static const double _clumpTop = 0.45;

  /// As a fraction of the spread.
  static const double _leafLength = 0.6;

  /// Aura bloom distance from the crown centre,
  static const double _auraOffset = 1.15;

  /// and each bloom's size.
  static const double _auraPetal = 0.3;

  /// Enough to read as a ring, few enough not to merge into a disc.
  static const int _auraBlooms = 7;

  /// Crown radius, rise and reach, computed in one place because [paint] uses
  /// the rise to place the stem and [footprintIn] uses the reach.
  ({double radius, double rise, double reach}) _crownGeometry(double spread) {
    // No crown until nearly grown.
    if (stage != GrowthStage.maturing && stage != GrowthStage.mature) {
      return (radius: 0, rise: 0, reach: 0);
    }

    final isOpen = stage == GrowthStage.mature;

    return switch (_crown) {
      // Open bloom reaches as far up as sideways; a bud is an oval.
      _Crown.bloom when isOpen => _bloom(spread * 0.42),
      _Crown.bloom => _bud(spread * 0.5),
      _Crown.tuft => _clump(spread * (isOpen ? 0.75 : 0.55)),
      _Crown.canopy => _clump(spread * (isOpen ? 1 : 0.7)),
      // Halo only once open, so the final stage is what reads as the award.
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

  /// A clump with a ring of blooms outside it. Takes the max of clump and
  /// halo for rise and reach so the footprint covers both.
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
        // Trunks use the soil colour; stems are green.
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
          // Five petals round a centre; bloom colour only on opened
          // flowers.
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
          // Closed green bud, so opening at 100% is a visible change.
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
          // A touch of colour, much less than a flower.
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
        // Ring of blooms, drawn after the clump so it sits in front.
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

  /// Three overlapping circles: cheapest thing that reads as foliage rather
  /// than a ball.
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
