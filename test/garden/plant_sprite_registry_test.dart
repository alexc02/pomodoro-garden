import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pip_garden/src/garden/plant_sprite.dart';

const _registry = PlaceholderPlantSpriteRegistry();

const _palette = PlantPalette(
  foliage: Color(0xFF6B8E5A),
  bloom: Color(0xFFE89B9B),
  soil: Color(0xFF8B6F47),
);

const double _side = 120;
const Rect _bounds = Rect.fromLTWH(0, 0, _side, _side);

/// The pixels a sprite actually puts on a canvas.
///
/// Drawn for real rather than asserted against a description of the drawing:
/// the thing this ticket promises is that a plant visibly changes as a session
/// runs, and only the pixels can say whether it did.
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

/// How many pixels the sprite covered.
int _inked(Uint8List pixels) {
  var count = 0;
  for (var i = 3; i < pixels.length; i += 4) {
    if (pixels[i] > 0) count++;
  }
  return count;
}

/// How tall the drawing stands off the bottom of the box, in pixels.
///
/// The plain reading of "it grew": the top of the plant moved up. Area would
/// not do — a bush is shorter than a flower and covers more of the plot — but
/// within one type every stage stands taller than the last.
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
            _registry.spriteFor(type: type, stage: stage),
            isNotNull,
            reason: '${type.name} at ${stage.name}',
          );
        }
      }
    });

    test('returns the same sprite for the same key', () {
      // Ticket 07 asks for a sprite per plant per frame. Looking one up must
      // not allocate.
      expect(
        _registry.spriteFor(
          type: PlantType.flower,
          stage: GrowthStage.mature,
        ),
        same(
          _registry.spriteFor(
            type: PlantType.flower,
            stage: GrowthStage.mature,
          ),
        ),
      );
    });

    test('gives every key its own sprite', () {
      final sprites = {
        for (final type in PlantType.values)
          for (final stage in GrowthStage.values)
            _registry.spriteFor(type: type, stage: stage),
      };

      expect(sprites, hasLength(PlantType.values.length * 5));
    });
  });

  group('what gets drawn', () {
    test('every sprite puts something on the canvas', () async {
      for (final type in PlantType.values) {
        for (final stage in GrowthStage.values) {
          final pixels =
              await _render(_registry.spriteFor(type: type, stage: stage));
          expect(_inked(pixels), greaterThan(0),
              reason: '${type.name} at ${stage.name} drew nothing');
        }
      }
    });

    test('each stage looks different from the one before it', () async {
      // The promise of the ticket, checked at the pixels: a user watching a
      // session sees the plant change four times.
      for (final type in PlantType.values) {
        var previous = await _render(
          _registry.spriteFor(type: type, stage: GrowthStage.seed),
        );

        for (final stage in GrowthStage.values.skip(1)) {
          final pixels =
              await _render(_registry.spriteFor(type: type, stage: stage));
          expect(pixels, isNot(previous),
              reason: '${type.name} does not change at ${stage.name}');
          previous = pixels;
        }
      }
    });

    test('a plant stands taller at every stage', () async {
      for (final type in PlantType.values) {
        var previous = 0;

        for (final stage in GrowthStage.values) {
          final height =
              _height(await _render(_registry.spriteFor(type: type, stage: stage)));
          expect(height, greaterThan(previous),
              reason: '${type.name} did not grow at ${stage.name}');
          previous = height;
        }
      }
    });

    test('a longer session grows a visibly bigger plant', () async {
      // REQ-015's reward tiers, at the pixels. Not asserted as a total order:
      // a bush is shorter than a flower and denser than one, exactly as the
      // requirement describes them. What must hold is that the ends of the
      // scale are nowhere near each other.
      Future<int> mature(PlantType type) async => _inked(
            await _render(
              _registry.spriteFor(type: type, stage: GrowthStage.mature),
            ),
          );

      expect(await mature(PlantType.wildflower),
          lessThan(await mature(PlantType.largeTree)),
          reason: 'a wildflower should not rival a large tree');
      expect(await mature(PlantType.herb),
          lessThan(await mature(PlantType.smallTree)));
      expect(
        _height(
          await _render(
            _registry.spriteFor(
              type: PlantType.largeTree,
              stage: GrowthStage.mature,
            ),
          ),
        ),
        greaterThan(
          _height(
            await _render(
              _registry.spriteFor(
                type: PlantType.wildflower,
                stage: GrowthStage.mature,
              ),
            ),
          ),
        ),
      );
    });

    test('every seed looks the same, whatever it will become', () async {
      // A session that has just started has not revealed what it is growing —
      // and it should not, because the plant is the reward for finishing.
      final seed = await _render(
        _registry.spriteFor(
          type: PlantType.wildflower,
          stage: GrowthStage.seed,
        ),
      );

      for (final type in PlantType.values) {
        expect(
          await _render(_registry.spriteFor(type: type, stage: GrowthStage.seed)),
          seed,
          reason: '${type.name} gave its size away as a seed',
        );
      }
    });

    test('an empty box is drawn into without complaint', () async {
      // A plant in a collapsed layout is a layout bug, not a crash.
      final recorder = PictureRecorder();
      expect(
        () => _registry
            .spriteFor(type: PlantType.largeTree, stage: GrowthStage.mature)
            .paint(Canvas(recorder), Rect.zero, _palette),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });
  });
}
