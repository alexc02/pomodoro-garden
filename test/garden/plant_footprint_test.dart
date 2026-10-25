import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pip_garden/src/garden/plant_sprite.dart';

/// What a sprite says it covers, checked against what it actually inks.
///
/// The footprint is what ticket 12's hit-test decides on, so a footprint that
/// disagreed with the drawing would send a tap to the wrong plant — and the
/// disagreement would be invisible, because nothing draws the box. Asserted at
/// the pixels for the same reason `plant_sprite_registry_test.dart` is: only
/// the pixels know where the plant went.

const _registry = PlaceholderPlantSpriteRegistry();

const _palette = PlantPalette(
  foliage: Color(0xFF6B8E5A),
  bloom: Color(0xFFE89B9B),
  soil: Color(0xFF8B6F47),
);

/// Big enough that a pixel is a small fraction of the plant, so the assertions
/// below are about the geometry rather than about rounding.
const int _side = 240;
const Rect _bounds = Rect.fromLTWH(0, 0, _side * 1.0, _side * 1.0);

/// The box around every pixel the sprite put down, or null if it drew nothing.
Future<Rect?> _inkedBounds(PlantSprite sprite) async {
  final recorder = PictureRecorder();
  sprite.paint(Canvas(recorder), _bounds, _palette);
  final picture = recorder.endRecording();
  final image = await picture.toImage(_side, _side);
  final data = (await image.toByteData())!.buffer.asUint8List();
  picture.dispose();
  image.dispose();

  int? left, top, right, bottom;
  for (var row = 0; row < _side; row++) {
    for (var column = 0; column < _side; column++) {
      if (data[((row * _side) + column) * 4 + 3] == 0) continue;
      left = left == null ? column : (column < left ? column : left);
      right = right == null ? column : (column > right ? column : right);
      top ??= row;
      bottom = row;
    }
  }

  if (left == null) return null;
  // Inclusive pixel indices to a rectangle: the pixel at `right` occupies up
  // to `right + 1`.
  return Rect.fromLTRB(
    left.toDouble(),
    top!.toDouble(),
    right! + 1,
    bottom! + 1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every plant is inside the footprint it claims', () async {
    // The half that matters: a tap anywhere on the plant must find it. A
    // footprint smaller than the drawing is a plant with an untappable edge.
    for (final type in PlantType.values) {
      for (final stage in GrowthStage.values) {
        final sprite = _registry.spriteFor(type: type, stage: stage);
        final ink = await _inkedBounds(sprite);
        // A drawing that ran off the canvas would make this test lie about
        // where the plant ends; the sprites are drawn to fit their box.
        expect(ink, isNotNull, reason: '${type.name} at ${stage.name}');

        final claimed = sprite.footprintIn(_bounds);
        // A pixel of slack for antialiasing, which spreads ink half a pixel
        // past the geometry on every edge.
        expect(
          claimed.inflate(1.5).contains(ink!.topLeft) &&
              claimed.inflate(1.5).contains(ink.bottomRight),
          isTrue,
          reason: '${type.name} at ${stage.name} inked $ink '
              'but claims only $claimed',
        );
      }
    }
  });

  test('and fills most of it', () async {
    // The other half: a footprint that claimed the whole box would hand a
    // wildflower every tap meant for the tree standing behind it, which is the
    // exact failure ticket 12 asks hit-testing to fix.
    for (final type in PlantType.values) {
      for (final stage in GrowthStage.values.skip(1)) {
        final sprite = _registry.spriteFor(type: type, stage: stage);
        final ink = (await _inkedBounds(sprite))!;
        final claimed = sprite.footprintIn(_bounds);

        expect(
          ink.height / claimed.height,
          greaterThan(0.8),
          reason: '${type.name} at ${stage.name} claims '
              '${claimed.height} tall and inks ${ink.height}',
        );
        expect(
          ink.width / claimed.width,
          greaterThan(0.6),
          reason: '${type.name} at ${stage.name} claims '
              '${claimed.width} wide and inks ${ink.width}',
        );
      }
    }
  });

  test('a plant stands on the soil, not over it', () async {
    // The footprint's bottom edge is what makes a tap on a plant's feet find
    // the plant: it has to reach the ground the plant is standing on.
    for (final type in PlantType.values) {
      final claimed = _registry
          .spriteFor(type: type, stage: GrowthStage.mature)
          .footprintIn(_bounds);

      expect(claimed.bottom, greaterThanOrEqualTo(_bounds.bottom));
      expect(claimed.center.dx, closeTo(_bounds.center.dx, 0.001));
    }
  });

  test('a bigger plant claims more room than a smaller one', () async {
    Rect mature(PlantType type) => _registry
        .spriteFor(type: type, stage: GrowthStage.mature)
        .footprintIn(_bounds);

    expect(
      mature(PlantType.largeTree).height,
      greaterThan(mature(PlantType.wildflower).height),
    );
    expect(
      mature(PlantType.largeTree).width,
      greaterThan(mature(PlantType.herb).width),
    );
  });

  test('an empty box is claimed by nothing', () {
    // A plant in a collapsed layout is a layout bug, not a crash — and not a
    // footprint that swallows every tap on the screen either.
    expect(
      _registry
          .spriteFor(type: PlantType.largeTree, stage: GrowthStage.mature)
          .footprintIn(Rect.zero),
      Rect.zero,
    );
  });
}
