import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/garden/decor_sprite.dart';
import 'package:pip_garden/src/garden/image_sprites.dart';

/// Which colour a decor mask's green channel stands for, per object.
///
/// Water and glow share it (`ImageDecorSprite`). Found in ticket 35: the
/// birdbath's water was served in the lantern's glow.
void main() {
  const palette = DecorPalette(
    material: ui.Color(0xFF808080),
    water: ui.Color(0xFF0000FF),
    shade: ui.Color(0xFF404040),
    glow: ui.Color(0xFFFF0000),
  );

  Future<ui.Image> solid(int r, int g, int b) {
    final pixels = Uint8List(4 * 4 * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      pixels
        ..[i] = r
        ..[i + 1] = g
        ..[i + 2] = b
        ..[i + 3] = 255;
    }
    final done = ui.ImmutableBuffer.fromUint8List(pixels).then(
      (buffer) => ui.ImageDescriptor.raw(
        buffer,
        width: 4,
        height: 4,
        pixelFormat: ui.PixelFormat.rgba8888,
      ).instantiateCodec(),
    );
    return done.then((codec) => codec.getNextFrame()).then((f) => f.image);
  }

  /// The colour [kind] paints where its mask is fully green.
  Future<ui.Color> greenOf(DecorKind kind) async {
    final art = await solid(255, 255, 255);
    final mask = await solid(0, 255, 0);
    final sprite = ImageDecorSprite(
      ImageSpriteArt(
        art: art,
        roles: mask,
        footprint: const ui.Rect.fromLTWH(0, 0, 1, 1),
      ),
      kind: kind,
    );

    final recorder = ui.PictureRecorder();
    sprite.paint(
      ui.Canvas(recorder),
      const ui.Rect.fromLTWH(0, 0, 4, 4),
      palette,
    );
    final image = await recorder.endRecording().toImage(4, 4);
    final bytes = (await image.toByteData())!;
    final pixel = bytes.getUint32(2 * 4 * 4 + 2 * 4); // RGBA at (2, 2)
    return ui.Color.fromARGB(
      pixel & 0xFF,
      pixel >> 24 & 0xFF,
      pixel >> 16 & 0xFF,
      pixel >> 8 & 0xFF,
    );
  }

  test('a lantern\'s green is its glow', () async {
    final colour = await greenOf(DecorKind.lantern);
    expect((colour.r * 255).round(), 255);
    expect((colour.b * 255).round(), 0);
  });

  for (final kind in [DecorKind.pond, DecorKind.birdbath]) {
    test('a ${kind.name}\'s green is its water', () async {
      final colour = await greenOf(kind);
      expect((colour.b * 255).round(), 255);
      expect((colour.r * 255).round(), 0);
    });
  }
}
