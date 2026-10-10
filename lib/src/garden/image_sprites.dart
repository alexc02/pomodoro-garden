import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'decor_sprite.dart';
import 'plant_sprite.dart';

/// A sprite backed by a decoded image instead of by canvas primitives — the
/// form ticket 23's watercolour art arrives in.
///
/// **This is the whole of what ticket 04's seam promised, made real.** A
/// [PlantSprite] paints rather than returning an `ImageProvider` precisely so
/// that both a handful of circles and a decoded PNG can satisfy it, and until
/// now only the first half of that claim had ever been run. Nothing above this
/// class changes when the art lands: the atlas bakes it into a cell the same
/// way, the garden batches it the same way, the hit-test asks it for the same
/// footprint.
///
/// ## The two images, and why there are two
///
/// A watercolour plant is a fixed picture. The palette is not: [PlantPalette]
/// is how a basil is a different green from a mint (species), how the garden
/// turns in October (ticket 14) and how a meadow differs from a Zen garden
/// (ticket 19). Thirty fixed PNGs would take all three of those away, and the
/// PRD's own asset plan assumes they do not — §9.1 commissions *six types × five
/// stages*, with seasonal variants listed for backgrounds and for nothing else.
///
/// So a sprite is delivered as:
///
/// - **[art]** — the drawing, full-colour RGBA with a transparent background.
///   This is what the illustrator paints and it is drawn as-is.
/// - **[roles]** — an optional mask the same size, in which each channel says
///   how much of a pixel belongs to one palette role: **red is foliage, green
///   is bloom, blue is soil.** Where a channel is zero the art keeps its own
///   colour; where it is full the palette's colour replaces it; in between they
///   blend, which is the setting a wash actually wants.
///
/// A sprite with no [roles] mask is legal and is simply art the palette cannot
/// reach — appropriate for something that should look the same in every season,
/// and wrong for a plant. `docs/art-pipeline.md` is the delivery contract.
///
/// ## Why the tint is `srcATop`
///
/// It leaves the destination alone wherever the mask is transparent, which is
/// what makes "the palette reaches only the parts the illustrator marked" true
/// rather than approximate. The alternative worth naming is `modulate`, which
/// multiplies alpha as well and therefore erases the drawing everywhere the
/// mask is empty.
///
/// The three tints go inside a [Canvas.saveLayer] because `srcATop` composites
/// against whatever is already on the canvas. Without the layer, a plant painted
/// over ticket 04's soil on the timer screen would tint the soil too wherever
/// its mask overlapped. The layer costs one offscreen per sprite — paid once per
/// bake in the garden, where it is nothing, and once per frame on the timer
/// screen, where there is exactly one plant.
///
/// ## Why this is not itself a sprite
///
/// [PlantSprite.paint] and [DecorSprite.paint] take different palettes, so no
/// one class can satisfy both. The drawing is the same either way, so it lives
/// here once and [ImagePlantSprite] and [ImageDecorSprite] are the two-line
/// adapters that say which four colours their palette lends to which three
/// channels.
final class ImageSpriteArt {
  const ImageSpriteArt({
    required this.art,
    required this.footprint,
    this.roles,
  });

  /// The drawing: full-colour, transparent background, any size.
  ///
  /// Scaled into whatever `bounds` it is given rather than assumed to match
  /// them — the atlas bakes into a 192-pixel cell and the timer screen draws at
  /// the width of a plot, and one image serves both.
  final Image art;

  /// Which palette role each pixel belongs to — red foliage, green bloom, blue
  /// soil — or null for art the palette does not reach.
  final Image? roles;

  /// How much of its box the drawing fills, as fractions of that box.
  ///
  /// **Carried rather than computed**, and that is a launch-budget decision. The
  /// honest way to find it is to scan the alpha channel for its tight bounds,
  /// which is some tens of milliseconds across sixty-five images — on the cold
  /// path, against PRD §4.4's 1.5 seconds. It is computed once when the art is
  /// built and shipped in the manifest beside it instead. See `ArtManifest`.
  final Rect footprint;

  /// Draws the art into [bounds] and tints it by [roles], red channel first.
  ///
  /// [roleColours] is red, green, blue in that order — three colours, whatever
  /// the caller's palette calls them.
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

    // Isolated, so `srcATop` composites against this sprite and not against
    // whatever the caller had already drawn underneath it.
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

  /// [footprint] scaled into [bounds], which is what both sprite interfaces
  /// mean by the same method name.
  Rect footprintIn(Rect bounds) => Rect.fromLTRB(
        bounds.left + footprint.left * bounds.width,
        bounds.top + footprint.top * bounds.height,
        bounds.left + footprint.right * bounds.width,
        bounds.top + footprint.bottom * bounds.height,
      );

  /// A filter that throws away the mask's colour and keeps one channel of it as
  /// coverage: every pixel becomes [colour], at the alpha channel [channel] was
  /// carrying.
  ///
  /// The matrix is 4×5 over RGBA with the last column an offset in 0–255. The
  /// first three rows are constant, which is the "throw the colour away" half;
  /// the fourth picks one input channel into alpha, which is the "keep the
  /// coverage" half. The mask's own alpha is deliberately not consulted — a
  /// role map is read by channel, so an illustrator can leave it fully opaque.
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

  /// Releases both textures.
  void dispose() {
    art.dispose();
    roles?.dispose();
  }

  /// Medium quality for the reason `GardenAtlas` gives about its own blit: the
  /// art is commissioned above every size it is drawn at, so this is almost
  /// always sampling *down*, which is what mipmapping is for.
  static final Paint _blit = Paint()..filterQuality = FilterQuality.medium;
}

/// A plant, drawn from art. Lends foliage, bloom and soil to red, green, blue.
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

/// An object, drawn from art.
///
/// Four palette colours into three channels: **water and glow share green**,
/// which is the one place this mapping loses something. It is the right thing
/// to lose — no object in REQ-040's set both holds water and gives off light,
/// so the lantern spends green on its flame and the pond and the birdbath
/// spend it on their water, and none of them ever needs the other. If a fifth
/// object ever needs both, this is the line that has to become a fourth
/// channel.
///
/// The lantern is named rather than the water-holders: it is the one object
/// that gives off light. An earlier version named the pond alone, and so served
/// the birdbath's water in lantern-glow (found in ticket 35).
final class ImageDecorSprite implements DecorSprite {
  const ImageDecorSprite(this.art, {required this.kind});

  final ImageSpriteArt art;

  /// Which object this is, and so which colour green means for it.
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

/// The [PlantSpriteRegistry] ticket 23's art is served through.
///
/// A map, built once from images already decoded — see `ArtBundle`, which is
/// where the asynchrony lives. Nothing here awaits, because
/// [PlantSpriteRegistry.spriteFor] cannot: ticket 07 asks this for a sprite per
/// plant per frame with two hundred plants on screen.
final class ImagePlantSpriteRegistry implements PlantSpriteRegistry {
  const ImagePlantSpriteRegistry(this._sprites);

  final Map<(PlantType, GrowthStage), ImagePlantSprite> _sprites;

  /// Every sprite this registry hands out, for the one caller that needs to
  /// walk them rather than look one up: `ArtBundle.dispose`.
  Iterable<ImageSpriteArt> get sprites =>
      _sprites.values.map((sprite) => sprite.art);

  /// Total over all thirty-five type/stage pairs, or it is not built.
  ///
  /// Checked when the bundle is loaded rather than answered with a null here,
  /// because a plant that cannot draw is a garden with a hole in it and the
  /// place to find that out is at launch, not at paint time.
  @override
  PlantSprite spriteFor({
    required PlantType type,
    required GrowthStage stage,
  }) =>
      _sprites[(type, stage)]!;
}

/// The [DecorSpriteRegistry] half, on the same terms.
final class ImageDecorSpriteRegistry implements DecorSpriteRegistry {
  const ImageDecorSpriteRegistry(this._sprites);

  final Map<DecorKind, ImageDecorSprite> _sprites;

  /// As [ImagePlantSpriteRegistry.sprites].
  Iterable<ImageSpriteArt> get sprites =>
      _sprites.values.map((sprite) => sprite.art);

  @override
  DecorSprite spriteFor(DecorKind kind) => _sprites[kind]!;
}
