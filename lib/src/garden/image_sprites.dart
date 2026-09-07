import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'decor_sprite.dart';
import 'plant_sprite.dart';

/// The drawing behind an image-backed sprite: a decoded PNG plus an optional
/// role mask.
///
/// The art itself is fixed, but [PlantPalette] still has to change it (species
/// shade, season, theme), so a sprite ships as:
///
/// - [art]: full-colour RGBA on transparent, drawn as-is.
/// - [roles]: optional same-size mask; red = foliage, green = bloom,
///   blue = soil. 0 keeps the art's colour, full replaces it with the
///   palette's, in between blends.
///
/// No mask means the palette can't touch it (fine for decor that shouldn't
/// change, wrong for a plant). Contract is in `docs/art-pipeline.md`.
///
/// Tints use `srcATop` so unmasked pixels are left alone (`modulate` would
/// erase them), inside a [Canvas.saveLayer] so they don't also tint whatever
/// was drawn underneath, e.g. the soil on the timer screen.
///
/// Not a sprite itself because plant and decor sprites take different palette
/// types; [ImagePlantSprite] and [ImageDecorSprite] adapt it.
final class ImageSpriteArt {
  const ImageSpriteArt({
    required this.art,
    required this.footprint,
    this.roles,
  });

  /// Any size; scaled into whatever bounds it's drawn in.
  final Image art;

  /// Role mask (red foliage, green bloom, blue soil), or null.
  final Image? roles;

  /// How much of its box the drawing fills, as fractions. Precomputed into the
  /// manifest so launch doesn't scan every alpha channel (see `ArtManifest`).
  final Rect footprint;

  /// Draws the art into [bounds] and tints it by [roles]. [roleColours] maps
  /// to the red, green and blue channels in that order.
  void paintTinted(Canvas canvas, Rect bounds, List<Color> roleColours) {
    final source = Rect.fromLTWH(
      0,
      0,
      art.width.toDouble(),
      art.height.toDouble(),
    );

    final mask = roles;
    if (mask == null) {
      canvas.drawImageRect(art, source, bounds, _blit);
      return;
    }

    // Own layer so `srcATop` only composites against this sprite.
    canvas.saveLayer(bounds, Paint());
    canvas.drawImageRect(art, source, bounds, _blit);

    final maskSource = Rect.fromLTWH(
      0,
      0,
      mask.width.toDouble(),
      mask.height.toDouble(),
    );
    for (var channel = 0; channel < roleColours.length; channel++) {
      canvas.drawImageRect(
        mask,
        maskSource,
        bounds,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..blendMode = BlendMode.srcATop
          ..colorFilter = _tint(roleColours[channel], channel),
      );
    }
    canvas.restore();
  }

  /// [footprint] scaled into [bounds].
  Rect footprintIn(Rect bounds) => Rect.fromLTRB(
        bounds.left + footprint.left * bounds.width,
        bounds.top + footprint.top * bounds.height,
        bounds.left + footprint.right * bounds.width,
        bounds.top + footprint.bottom * bounds.height,
      );

  /// Every pixel becomes [colour], with alpha taken from one mask [channel].
  ///
  /// 4x5 RGBA matrix, last column an offset in 0-255. The mask's own alpha is
  /// ignored on purpose so role maps can be fully opaque.
  static ColorFilter _tint(Color colour, int channel) {
    final red = [1.0, 0.0, 0.0, 0.0];
    final green = [0.0, 1.0, 0.0, 0.0];
    final blue = [0.0, 0.0, 1.0, 0.0];
    final pick = [red, green, blue][channel];

    return ColorFilter.matrix(<double>[
      0, 0, 0, 0, colour.r * 255,
      0, 0, 0, 0, colour.g * 255,
      0, 0, 0, 0, colour.b * 255,
      ...pick, 0,
    ]);
  }

  void dispose() {
    art.dispose();
    roles?.dispose();
  }

  /// Medium quality: the art is always larger than it's drawn, so this is
  /// sampling down.
  static final Paint _blit = Paint()..filterQuality = FilterQuality.medium;
}

/// A plant drawn from art: foliage, bloom, soil go to red, green, blue.
final class ImagePlantSprite implements PlantSprite {
  const ImagePlantSprite(this.art);

  final ImageSpriteArt art;

  @override
  void paint(Canvas canvas, Rect bounds, PlantPalette palette) =>
      art.paintTinted(
        canvas,
        bounds,
        [palette.foliage, palette.bloom, palette.soil],
      );

  @override
  Rect footprintIn(Rect bounds) => art.footprintIn(bounds);
}

/// Decor drawn from art.
///
/// Four palette colours into three channels, so water and glow share green.
/// Fine as long as nothing both holds water and gives off light: the lantern
/// uses green for its flame, everything else for water. Matching on the
/// lantern (not the pond) matters, or the birdbath gets lantern-glow water.
final class ImageDecorSprite implements DecorSprite {
  const ImageDecorSprite(this.art, {required this.kind});

  final ImageSpriteArt art;

  /// Decides what green means for this object.
  final DecorKind kind;

  @override
  void paint(Canvas canvas, Rect bounds, DecorPalette palette) =>
      art.paintTinted(canvas, bounds, [
        palette.material,
        kind == DecorKind.lantern ? palette.glow : palette.water,
        palette.shade,
      ]);

  @override
  Rect footprintIn(Rect bounds) => art.footprintIn(bounds);
}

/// Image-backed [PlantSpriteRegistry]. Everything is decoded up front in
/// `ArtBundle`, since `spriteFor` is called per plant per frame and can't
/// await.
final class ImagePlantSpriteRegistry implements PlantSpriteRegistry {
  const ImagePlantSpriteRegistry(this._sprites);

  final Map<(PlantType, GrowthStage), ImagePlantSprite> _sprites;

  /// For `ArtBundle.dispose`.
  Iterable<ImageSpriteArt> get sprites =>
      _sprites.values.map((sprite) => sprite.art);

  /// Totality is checked when the bundle loads, so the `!` is safe.
  @override
  PlantSprite spriteFor({
    required PlantType type,
    required GrowthStage stage,
  }) =>
      _sprites[(type, stage)]!;
}

/// Image-backed [DecorSpriteRegistry].
final class ImageDecorSpriteRegistry implements DecorSpriteRegistry {
  const ImageDecorSpriteRegistry(this._sprites);

  final Map<DecorKind, ImageDecorSprite> _sprites;

  /// For `ArtBundle.dispose`.
  Iterable<ImageSpriteArt> get sprites =>
      _sprites.values.map((sprite) => sprite.art);

  @override
  DecorSprite spriteFor(DecorKind kind) => _sprites[kind]!;
}
