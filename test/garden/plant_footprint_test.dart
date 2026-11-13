import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pip_garden/src/garden/plant_sprite.dart';

// A sprite's footprint vs the pixels it actually inks. Hit-testing uses the
// footprint, and a mismatch would be invisible since nothing draws it.

const _registry = PlaceholderPlantSpriteRegistry();

/// The placeholders draw every form of a type alike, so any form will do.
PlantSprite _spriteFor(PlantType type, GrowthStage stage) =>
    _registry.spriteFor(form: PlantForm.of(type).first, stage: stage);

const _palette = PlantPalette(
  foliage: Color(0xFF6B8E5A),
  bloom: Color(0xFFE89B9B),
  soil: Color(0xFF8B6F47),
);

/// Big enough that rounding doesn't matter.
const int _side = 240;
const Rect _bounds = Rect.fromLTWH(0, 0, _side * 1.0, _side * 1.0);

/// Bounds of all inked pixels, or null if nothing was drawn.
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
  // Inclusive indices to a rect: pixel `right` spans to `right + 1`.
  return Rect.fromLTRB(
    left.toDouble(),
    top!.toDouble(),
    right! + 1,
    bottom! + 1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every plant is inside its footprint', () async {
    // A footprint smaller than the drawing leaves an untappable edge.
    for (final type in PlantType.values) {
      for (final stage in GrowthStage.values) {
        final sprite = _spriteFor(type, stage);
        final ink = await _inkedBounds(sprite);
        expect(ink, isNotNull, reason: '${type.name} at ${stage.name}');

        final claimed = sprite.footprintIn(_bounds);
        // A pixel of slack for antialiasing.
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

  test('fills most of it', () async {
    // A footprint claiming the whole box would steal taps from the plant
    // behind.
    for (final type in PlantType.values) {
      for (final stage in GrowthStage.values.skip(1)) {
        final sprite = _spriteFor(type, stage);
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

  test('footprint reaches the soil', () async {
    // The bottom edge has to reach the ground so a tap at the base works.
    for (final type in PlantType.values) {
      final claimed = _spriteFor(type, GrowthStage.mature).footprintIn(_bounds);

      expect(claimed.bottom, greaterThanOrEqualTo(_bounds.bottom));
      expect(claimed.center.dx, closeTo(_bounds.center.dx, 0.001));
    }
  });

  test('bigger plant has a bigger footprint', () async {
    Rect mature(PlantType type) => _spriteFor(type, GrowthStage.mature)
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

  test('empty box claims nothing', () {
    // A collapsed layout shouldn't crash or swallow every tap.
    expect(
      _spriteFor(PlantType.largeTree, GrowthStage.mature)
          .footprintIn(Rect.zero),
      Rect.zero,
    );
  });
}
