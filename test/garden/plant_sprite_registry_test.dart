import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pip_garden/src/garden/plant_sprite.dart';

const _registry = PlaceholderPlantSpriteRegistry();

/// The placeholders draw every form of a type alike, so any form will do.
PlantSprite _spriteFor(PlantType type, GrowthStage stage) =>
    _registry.spriteFor(form: PlantForm.of(type).first, stage: stage);

const _palette = PlantPalette(
  foliage: Color(0xFF6B8E5A),
  bloom: Color(0xFFE89B9B),
  soil: Color(0xFF8B6F47),
);

const double _side = 120;
const Rect _bounds = Rect.fromLTWH(0, 0, _side, _side);

/// Renders [sprite] and returns its pixels.
Future<Uint8List> _render(PlantSprite sprite) async {
  final recorder = PictureRecorder();
  sprite.paint(Canvas(recorder), _bounds, _palette);
  final picture = recorder.endRecording();
  final image = await picture.toImage(_side.toInt(), _side.toInt());
  final data = await image.toByteData();
  picture.dispose();
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Count of inked pixels.
int _inked(Uint8List pixels) {
  var count = 0;
  for (var i = 3; i < pixels.length; i += 4) {
    if (pixels[i] > 0) count++;
  }
  return count;
}

/// Height of the drawing above the bottom of the box, in pixels. Area
/// wouldn't work across types (a bush is shorter but covers more), but within
/// a type each stage is taller.
int _height(Uint8List pixels) {
  for (var row = 0; row < _side; row++) {
    for (var column = 0; column < _side; column++) {
      final alpha = pixels[((row * _side.toInt()) + column) * 4 + 3];
      if (alpha > 0) return _side.toInt() - row;
    }
  }
  return 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the registry', () {
    test('resolves all six types at all five stages', () {
      for (final type in PlantType.values) {
        for (final stage in GrowthStage.values) {
          expect(
            _spriteFor(type, stage),
            isNotNull,
            reason: '${type.name} at ${stage.name}',
          );
        }
      }
    });

    test('returns the same sprite for the same key', () {
      // Called per plant per frame, so lookup must not allocate.
      expect(
        _spriteFor(PlantType.flower, GrowthStage.mature),
        same(_spriteFor(PlantType.flower, GrowthStage.mature)),
      );
    });

    test('distinct sprite per key', () {
      final sprites = {
        for (final type in PlantType.values)
          for (final stage in GrowthStage.values)
            _spriteFor(type, stage),
      };

      expect(sprites, hasLength(PlantType.values.length * 5));
    });
  });

  group('what gets drawn', () {
    test('every sprite puts something on the canvas', () async {
      for (final type in PlantType.values) {
        for (final stage in GrowthStage.values) {
          final pixels = await _render(_spriteFor(type, stage));
          expect(_inked(pixels), greaterThan(0),
              reason: '${type.name} at ${stage.name} drew nothing');
        }
      }
    });

    test('each stage differs from the last', () async {
      // The plant should visibly change at each stage.
      for (final type in PlantType.values) {
        var previous = await _render(_spriteFor(type, GrowthStage.seed));

        for (final stage in GrowthStage.values.skip(1)) {
          final pixels = await _render(_spriteFor(type, stage));
          expect(pixels, isNot(previous),
              reason: '${type.name} does not change at ${stage.name}');
          previous = pixels;
        }
      }
    });

    test('taller at every stage', () async {
      for (final type in PlantType.values) {
        var previous = 0;

        for (final stage in GrowthStage.values) {
          final height = _height(await _render(_spriteFor(type, stage)));
          expect(height, greaterThan(previous),
              reason: '${type.name} did not grow at ${stage.name}');
          previous = height;
        }
      }
    });

    test('longer session grows a bigger plant', () async {
      // Not a total order (a bush is shorter and denser than a flower), but the
      // ends of the scale should be far apart.
      Future<int> mature(PlantType type) async => _inked(
            await _render(
              _spriteFor(type, GrowthStage.mature),
            ),
          );

      expect(await mature(PlantType.wildflower),
          lessThan(await mature(PlantType.largeTree)),
          reason: 'wildflower should be much smaller than a large tree');
      expect(await mature(PlantType.herb),
          lessThan(await mature(PlantType.smallTree)));
      expect(
        _height(
          await _render(
            _spriteFor(PlantType.largeTree, GrowthStage.mature),
          ),
        ),
        greaterThan(
          _height(
            await _render(
              _spriteFor(PlantType.wildflower, GrowthStage.mature),
            ),
          ),
        ),
      );
    });

    test('all seeds look the same', () async {
      // A fresh session shouldn't reveal what it's growing.
      final seed =
          await _render(_spriteFor(PlantType.wildflower, GrowthStage.seed));

      for (final type in PlantType.values) {
        expect(
          await _render(_spriteFor(type, GrowthStage.seed)),
          seed,
          reason: '${type.name} seed differs',
        );
      }
    });

    test('empty box draws without error', () async {
      // A plant in a collapsed layout is a layout bug, not a crash.
      final recorder = PictureRecorder();
      expect(
        () => _spriteFor(PlantType.largeTree, GrowthStage.mature)
            .paint(Canvas(recorder), Rect.zero, _palette),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });
  });
}
