import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/garden/decor_sprite.dart';
import 'package:pomodoro_garden/src/garden/placeholder_decor_sprites.dart';
import 'package:pomodoro_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pomodoro_garden/src/garden/plant_sprite.dart';

/// **Retired (ticket 35).** Built the stand-in art set under `assets/art/`,
/// and the manifest beside it, until the paper-cut set replaced it. Its one
/// test is skipped so that running it cannot overwrite the real art; the
/// generator now is `tool/generate_sprite_art.dart`. Kept for its account of
/// how a role mask is derived, which the new generator follows.
///
///     flutter test tool/generate_art.dart
///
/// It lives in `tool/` rather than `test/` so that `flutter test` does not run
/// it: it writes files, which is not a thing a test suite should do on its way
/// past. It is run by hand, and its output is committed.
///
/// ## What these are, and what they are not
///
/// **They are not the watercolour art.** PRD §9.1 commissions roughly a hundred
/// hand-drawn illustrations from a freelance illustrator, and ticket 23 is
/// waiting on that delivery. What this produces is ticket 04's placeholder
/// shapes — the same circles and lines the app has drawn since then —
/// *rasterised into PNGs* so that the image pipeline has something real to
/// carry.
///
/// That is deliberately the least interesting art possible, and it is the right
/// choice twice over. It means the pipeline is exercised with real files, real
/// decode cost, real transparency and real binary weight; and it means swapping
/// it for the real thing changes no pixel the app was relying on, because the
/// stand-ins *are* what the app already drew.
///
/// ## How a role mask gets made
///
/// This is the part worth understanding, because it is also how the illustrator's
/// masks will be checked. `ImageSpriteArt` tints art through a mask whose red,
/// green and blue channels are the coverage of foliage, bloom and soil. A
/// placeholder sprite already takes those three as a [PlantPalette] and paints
/// each part in its own colour — so painting one with a palette of **pure red,
/// pure green and pure blue** produces exactly the role mask for it. No
/// hand-authoring, and no chance of the mask disagreeing with the drawing.
///
/// The masks are drawn at [_maskAlpha] rather than fully opaque so that the
/// drawing's own wash still shows through the tint. At 1.0 the palette would
/// replace the art outright, which for a watercolour would throw away the thing
/// that makes it one.

/// The side of every drawing, in pixels.
///
/// PRD §9.1: *deliver at the highest density needed and downscale at build
/// time*. The largest this is ever drawn is the timer screen at 3× — 88 logical
/// points is 264 device pixels — and the garden's own ceiling is
/// `GardenAtlas.cellWidth`, which is 192. 512 clears both with room for a
/// device denser than any that ships, and it is a power of two.
const int _side = 512;

/// How much of the tint the palette gets, against the drawing's own colour.
const double _maskAlpha = 0.85;

/// The colours the stand-in drawings are painted in.
///
/// A muted wash rather than the app's real palette: what shows through the mask
/// is meant to read as *paper and pigment*, and the palette on top of it is
/// where the actual colour comes from. PRD §5.1's soil and garden green,
/// desaturated.
const PlantPalette _reference = PlantPalette(
  foliage: Color(0xFF7E9A70),
  bloom: Color(0xFFD9A9A9),
  soil: Color(0xFF9A836A),
);

const DecorPalette _referenceDecor = DecorPalette(
  material: Color(0xFF9A9A92),
  water: Color(0xFF9EC5DE),
  shade: Color(0xFF9A836A),
  glow: Color(0xFFE8C36B),
);

/// The palette that turns a drawing into its own role mask.
const PlantPalette _roles = PlantPalette(
  foliage: Color(0xFFFF0000),
  bloom: Color(0xFF00FF00),
  soil: Color(0xFF0000FF),
);

/// The decor equivalent. Green carries water *and* glow, which is the mapping
/// `ImageDecorSprite` reads back out — no object in REQ-036's set needs both.
const DecorPalette _rolesDecor = DecorPalette(
  material: Color(0xFFFF0000),
  water: Color(0xFF00FF00),
  shade: Color(0xFF0000FF),
  glow: Color(0xFF00FF00),
);

const String _directory = 'assets/art';

void main() {
  test('generate the stand-in art set', () async {
    const plants = PlaceholderPlantSpriteRegistry();
    const decor = PlaceholderDecorSpriteRegistry();
    final square = Rect.fromLTWH(0, 0, _side.toDouble(), _side.toDouble());

    Directory('$_directory/plants').createSync(recursive: true);
    Directory('$_directory/decor').createSync(recursive: true);

    final plantRows = <Map<String, Object?>>[];
    for (final type in PlantType.values) {
      for (final stage in GrowthStage.values) {
        final sprite = plants.spriteFor(type: type, stage: stage);
        final name = '${type.name}_${stage.name}';

        final footprint = await _write(
          '$_directory/plants/$name.png',
          (canvas) => sprite.paint(canvas, square, _reference),
        );
        await _write(
          '$_directory/plants/$name.roles.png',
          (canvas) => _atAlpha(
            canvas,
            square,
            (it) => sprite.paint(it, square, _roles),
          ),
        );

        plantRows.add({
          'type': type.name,
          'stage': stage.name,
          'art': '$_directory/plants/$name.png',
          'roles': '$_directory/plants/$name.roles.png',
          'footprint': footprint,
        });
      }
    }

    final decorRows = <Map<String, Object?>>[];
    for (final kind in DecorKind.values) {
      final sprite = decor.spriteFor(kind);

      final footprint = await _write(
        '$_directory/decor/${kind.name}.png',
        (canvas) => sprite.paint(canvas, square, _referenceDecor),
      );
      await _write(
        '$_directory/decor/${kind.name}.roles.png',
        (canvas) => _atAlpha(
          canvas,
          square,
          (it) => sprite.paint(it, square, _rolesDecor),
        ),
      );

      decorRows.add({
        'kind': kind.name,
        'art': '$_directory/decor/${kind.name}.png',
        'roles': '$_directory/decor/${kind.name}.roles.png',
        'footprint': footprint,
      });
    }

    File('$_directory/manifest.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({
            'note': 'Generated by tool/generate_art.dart. These are ticket 04 '
                'placeholder shapes rasterised, NOT the commissioned '
                'watercolour art. See docs/art-pipeline.md.',
            'side': _side,
            'plants': plantRows,
            'decor': decorRows,
          })}\n',
    );

    // ignore: avoid_print
    print('wrote ${plantRows.length} plants and ${decorRows.length} objects '
        'to $_directory');
  },
      skip: 'Retired by ticket 35. Every plant and object is now paper-cut art '
          'painted by tool/generate_sprite_art.dart; running this would '
          'overwrite all of it with ticket 04\'s placeholder shapes.');
}

/// Renders [draw] into a [_side]-square PNG at [path], and answers the tight
/// bounds of the ink that ended up in it, as the fractions the manifest carries.
///
/// **Measured from the file rather than asked of the sprite, and the difference
/// is not academic.** A placeholder sprite is entitled to say its footprint
/// overhangs its box — `PlantSprite.footprintIn` explicitly permits it, and
/// ticket 04's large tree claims to reach 5% above and below its square. A PNG
/// cannot: rasterising clips it. Taking the sprite's word for it wrote manifest
/// rows describing ink that is not in the file, and ticket 12 hit-tests against
/// those rows.
///
/// It is also what the illustrator's delivery has to do — there is no sprite to
/// ask, only an alpha channel to scan (`docs/art-pipeline.md`) — so the
/// stand-ins now go through the same step the real art will, rather than through
/// a shortcut only they have.
Future<List<double>> _write(String path, void Function(Canvas) draw) async {
  final recorder = PictureRecorder();
  draw(Canvas(recorder));
  final picture = recorder.endRecording();

  final image = await picture.toImage(_side, _side);
  picture.dispose();

  final pixels = await image.toByteData();
  final png = await image.toByteData(format: ImageByteFormat.png);
  image.dispose();

  File(path).writeAsBytesSync(png!.buffer.asUint8List());
  return _inkBounds(pixels!.buffer.asUint8List());
}

/// The tight bounds of the non-transparent pixels of a [_side]-square RGBA
/// buffer, as `[left, top, right, bottom]` fractions of it.
///
/// Right and bottom are exclusive: a single inked pixel in the leftmost column
/// occupies the span `[0, 1/_side)`, not the empty span `[0, 0)`.
List<double> _inkBounds(Uint8List rgba) {
  var left = _side, top = _side, right = -1, bottom = -1;
  for (var y = 0; y < _side; y++) {
    for (var x = 0; x < _side; x++) {
      if (rgba[(y * _side + x) * 4 + 3] == 0) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }

  if (right < 0) throw StateError('nothing was drawn');
  return [
    left / _side,
    top / _side,
    (right + 1) / _side,
    (bottom + 1) / _side,
  ];
}

/// Draws [inner] into a layer held back to [_maskAlpha].
void _atAlpha(Canvas canvas, Rect bounds, void Function(Canvas) inner) {
  canvas.saveLayer(
    bounds,
    Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: _maskAlpha),
  );
  inner(canvas);
  canvas.restore();
}
