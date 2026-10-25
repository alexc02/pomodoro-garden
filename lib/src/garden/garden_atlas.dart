import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../design/palette.dart';
import 'decor_sprite.dart';
import 'plant_sprite.dart';

/// Every picture the garden draws, baked into one texture.
///
/// The reason ticket 07's garden can afford two hundred plants: one image, one
/// `Canvas.drawAtlas` per frame, and the whole garden goes to the GPU as a
/// single batch of quads. Two hundred `drawCircle` calls per plant — which is
/// what asking each sprite to paint itself every frame would mean — is the same
/// picture at roughly a hundred times the per-frame work, and it is the way to
/// miss ticket 24's frame budget.
///
/// **One texture for the plants and REQ-040's decor together, and that is the
/// point of it.** A second atlas for the furniture would be a second
/// `drawAtlas` call and so a second batch, which would break the depth sort at
/// exactly the place it matters: a bench and the tree behind it have to be two
/// quads in one ordered list, or one of them is always in front.
///
/// The sprites are not replaced by this; they are *rendered through* it. A cell
/// is filled by asking [PlantSpriteRegistry] or [DecorSpriteRegistry] for a
/// sprite and letting it paint itself once, into an offscreen canvas, at bake
/// time. Ticket 23 supplies different registries and this file does not change
/// — the atlas is still built out of whatever they hand over, and if that turns
/// out to be a decoded PNG rather than a handful of circles, it is blitted into
/// the cell the same way.
///
/// A plant's colours are baked into its cell rather than tinted per instance.
/// `drawAtlas` can multiply one colour into a sprite, and a plant has three —
/// foliage, bloom and soil — so a single tint could not tell a sunflower from a
/// tulip. Seventeen species and four objects is a cheap enough atlas to bake
/// them properly.
///
/// Only [GrowthStage.mature] is baked, because only a completed session earns a
/// plant and a plant that reached the garden is by definition finished growing.
/// A garden that ever shows a half-grown plant adds a stage to the cell key;
/// nothing else about this changes.
final class GardenAtlas {
  /// The texture and its indexes are positional, because a named parameter
  /// cannot be private and none of them is part of this type's public shape.
  GardenAtlas._(
    this._image,
    this._plants,
    this._footprints,
    this._decor,
    this._decorFootprints, {
    required this.emptySoil,
    required this.plantedSoil,
    required this.glowHalo,
    required this.signature,
  });

  /// How wide the soil tile is baked, in texture pixels.
  ///
  /// Two to one like the tile it stands for, and generous enough that the
  /// garden at its maximum zoom is still sampling the texture down rather than
  /// up. The plant and decor cells are square and this wide.
  static const int cellWidth = 192;

  final Image _image;
  final Map<PlantSpecies, Rect> _plants;
  final Map<PlantSpecies, Rect> _footprints;
  final Map<DecorKind, Rect> _decor;
  final Map<DecorKind, Rect> _decorFootprints;

  /// Where an unplanted plot's tile is in the texture.
  final Rect emptySoil;

  /// Where an occupied plot's tile is.
  ///
  /// Occupied rather than *planted*: a plot with a bench in it is drawn on this
  /// one too. The tile says whether the ground is spoken for, and a plot the
  /// user has arranged something into is not somewhere anything else can go.
  final Rect plantedSoil;

  /// Where REQ-021's enchanted willow's halo is: a soft disc of light, baked
  /// in a square cell like a plant's and hung from the same anchor, so the
  /// painter can lay it behind the willow in the same batch (PRD v2.2).
  final Rect glowHalo;

  /// What this atlas was baked from.
  ///
  /// Held so a caller can tell whether the atlas it has is still the right one
  /// — the colours come from the theme, and the theme changes when the user's
  /// phone goes dark. Compared rather than recomputed, so a rebuild that
  /// changed nothing does not rebake a texture.
  final GardenAtlasRecipe signature;

  /// Where [species] is in the texture.
  ///
  /// Total over [PlantSpecies], so no plant in the garden can fail to draw.
  Rect rectFor(PlantSpecies species) => _plants[species]!;

  /// Where [kind] is in the texture. Total over [DecorKind].
  Rect rectForDecor(DecorKind kind) => _decor[kind]!;

  /// How much of its cell [species]'s picture fills, as fractions of that cell:
  /// `Rect.fromLTRB(0, 0, 1, 1)` is all of it, and a wildflower is a strip
  /// along the bottom.
  ///
  /// Here rather than asked of the registry directly, and that is the whole
  /// point of it being here: ticket 12 hit-tests against this number, and a
  /// hit-test that asked the registry for a sprite of its own would have to
  /// repeat [bake]'s decision about *which* sprite goes in a plant's cell. Two
  /// copies of that decision is one bug — a tap landing on the wrong plant,
  /// silently — the first time a garden holds something that is not a mature
  /// plant of its own species' type. The atlas made the choice, so the atlas
  /// answers for it.
  ///
  /// Fractions rather than pixels because the cell is baked at [cellWidth] and
  /// drawn at whatever the zoom says; a caller scales these into the box it is
  /// drawing the plant in, which is the same scaling [drawInto] applies to the
  /// picture itself.
  Rect footprintFor(PlantSpecies species) => _footprints[species]!;

  /// How much of its cell [kind]'s picture fills, on the same terms and for the
  /// same reason: a pond is a wide flat oval and a lantern is a narrow upright,
  /// and a tap has to be able to tell them apart from the plants around them.
  Rect footprintForDecor(DecorKind kind) => _decorFootprints[kind]!;

  /// The side of a plant's square cell, in texture pixels. What
  /// [RSTransform.fromComponents] scales against.
  double get plantCell => cellWidth.toDouble();

  /// Draws [rects] of this texture at [transforms], in one call.
  ///
  /// The only way anything gets at the image, and the reason `drawAtlas` is not
  /// spread across the painter: `test/garden/sprites_are_the_only_art_test.dart`
  /// allows exactly the files that are permitted to know what a plant looks
  /// like, and keeping the blit here keeps the painter out of that list.
  ///
  /// [colors], when given, washes each quad with its colour over the picture:
  /// REQ-021's golden shimmer, carried in the same call rather than a second
  /// one. `drawAtlas` blends with the colour as the *destination* and the
  /// picture as the source, so the mode is `dstATop` — the colour laid over
  /// the picture inside the picture's own shape. A transparent colour leaves a
  /// quad exactly as it was. (`srcATop` reads as the right mode and is not: it
  /// keeps the colour's alpha, and fades the whole garden — found in ticket
  /// 36, and pinned by `garden_glow_test.dart`'s pixel test.)
  void drawInto(
    Canvas canvas, {
    required List<RSTransform> transforms,
    required List<Rect> rects,
    List<Color>? colors,
  }) {
    if (transforms.isEmpty) return;
    canvas.drawAtlas(
      _image,
      transforms,
      rects,
      colors,
      colors == null ? null : BlendMode.dstATop,
      null,
      _blit,
    );
  }

  /// Held rather than built per call: this runs once a frame for as long as the
  /// user is dragging, and nothing mutates it.
  ///
  /// Medium quality rather than low, because the garden is almost always
  /// sampling the texture *down* — a plot is 88 logical pixels wide and its cell
  /// is 192 — and that is exactly the case mipmapping is for. Left at low, a
  /// zoomed-out garden shimmers as it moves.
  static final Paint _blit = Paint()..filterQuality = FilterQuality.medium;

  /// Releases the texture. Called when the widget holding it goes, or when the
  /// theme changes under it and a new one is baked.
  void dispose() => _image.dispose();

  /// Bakes an atlas from [recipe].
  ///
  /// Synchronous, through `Picture.toImageSync`, and that is worth the note: an
  /// async bake would mean the garden had a frame with no texture to draw, and
  /// so a loading state, on a screen whose entire job is to be there instantly.
  static GardenAtlas bake(GardenAtlasRecipe recipe) {
    const species = PlantSpecies.values;
    const decor = DecorKind.values;
    // The plants and the objects share one grid of square cells, in that order.
    // Sharing it rather than giving decor a strip of its own keeps the sheet
    // square-ish, which is what wastes the least texture.
    // One more cell after the objects, for the enchanted willow's halo.
    final cells = species.length + decor.length + 1;
    // A square-ish sheet: fewer, wider rows waste less of the texture than a
    // single strip, and the GPU has a maximum texture width that a strip of
    // twenty-one cells would be uncomfortably close to on older devices.
    final columns = math.sqrt(cells).ceil();
    final rows = (cells / columns).ceil();

    const int pad = _padding;
    final sheetWidth = columns * (cellWidth + pad) + pad;
    // The cell grid, and then one row for the two soil tiles, which are half
    // as tall because a tile is twice as wide as it is deep.
    final soilTop = rows * (cellWidth + pad) + pad;
    final sheetHeight = soilTop + cellWidth ~/ 2 + pad;

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    /// Where the [index]th cell of the shared grid is.
    Rect cellAt(int index) => Rect.fromLTWH(
          ((index % columns) * (cellWidth + pad) + pad).toDouble(),
          ((index ~/ columns) * (cellWidth + pad) + pad).toDouble(),
          cellWidth.toDouble(),
          cellWidth.toDouble(),
        );

    /// The picture's own bounds inside a cell, as fractions of it.
    ///
    /// Measured against the cell it was painted into rather than against a unit
    /// square: a sprite is entitled to a detail that does not scale — the
    /// placeholders' stems have a minimum stroke width — and the honest
    /// footprint is the one taken at the size the picture was actually baked.
    Rect fractionsOf(Rect footprint, Rect square) => Rect.fromLTRB(
          footprint.left / square.width,
          footprint.top / square.height,
          footprint.right / square.width,
          footprint.bottom / square.height,
        );

    final plants = <PlantSpecies, Rect>{};
    final footprints = <PlantSpecies, Rect>{};
    for (var index = 0; index < species.length; index++) {
      final cell = cellAt(index);
      plants[species[index]] = cell;

      // The one place that decides which picture a plant gets. Everything the
      // garden knows about that plant's picture — where it is in the texture
      // and how much of its cell it fills — comes out of this sprite and no
      // other, so the two cannot disagree about which plant is being drawn.
      final sprite = recipe.registry
          .spriteFor(type: species[index].type, stage: GrowthStage.mature);
      final square = Rect.fromLTWH(0, 0, cell.width, cell.height);

      canvas.save();
      canvas.translate(cell.left, cell.top);
      // The sprite paints standing on the bottom edge of what it is given,
      // which is what puts a plant's base at the bottom of its cell — and so at
      // the anchor the garden hangs it from.
      sprite.paint(canvas, square, recipe.palettes[species[index]]!);
      canvas.restore();

      footprints[species[index]] = fractionsOf(sprite.footprintIn(square), square);
    }

    final objects = <DecorKind, Rect>{};
    final decorFootprints = <DecorKind, Rect>{};
    for (var index = 0; index < decor.length; index++) {
      final cell = cellAt(species.length + index);
      objects[decor[index]] = cell;

      // Baked exactly as a plant is, and from the same square: an object stands
      // on the bottom edge of its cell, so the painter can hang a bench and an
      // oak from one anchor and neither has to know which it is drawing.
      final sprite = recipe.decorRegistry.spriteFor(decor[index]);
      final square = Rect.fromLTWH(0, 0, cell.width, cell.height);

      canvas.save();
      canvas.translate(cell.left, cell.top);
      sprite.paint(canvas, square, recipe.decorPalette);
      canvas.restore();

      decorFootprints[decor[index]] =
          fractionsOf(sprite.footprintIn(square), square);
    }

    // REQ-021's halo: light gathered where the willow's crown is, fading to
    // nothing well inside the cell so its edge never shows.
    final halo = cellAt(species.length + decor.length);
    final light = Color.lerp(
      recipe.decorPalette.glow,
      const Color(0xFFFFF6D8),
      0.6,
    )!;
    canvas.drawRect(
      halo,
      Paint()
        ..shader = Gradient.radial(
          Offset(halo.center.dx, halo.top + halo.height * 0.375),
          halo.width * 0.5,
          [
            light.withValues(alpha: 0.7),
            light.withValues(alpha: 0.3),
            light.withValues(alpha: 0),
          ],
          const [0, 0.55, 1],
        ),
    );

    final empty = Rect.fromLTWH(
      pad.toDouble(),
      soilTop.toDouble(),
      cellWidth.toDouble(),
      cellWidth / 2,
    );
    final planted = empty.translate((cellWidth + pad).toDouble(), 0);
    _paintSoil(canvas, empty, recipe.soil, recipe.decor, planted: false);
    _paintSoil(canvas, planted, recipe.soil, recipe.decor, planted: true);

    final picture = recorder.endRecording();
    final image = picture.toImageSync(sheetWidth, sheetHeight);
    picture.dispose();

    return GardenAtlas._(
      image,
      plants,
      footprints,
      objects,
      decorFootprints,
      emptySoil: empty,
      plantedSoil: planted,
      glowHalo: halo,
      signature: recipe,
    );
  }

  /// A gap between cells, so that filtering a scaled-down atlas cannot drag a
  /// neighbour's pixels into a sprite's edge.
  static const int _padding = 2;

  /// One plot's ground: a diamond, filling [cell], cut from paper (PRD v2.2
  /// §9.1).
  ///
  /// Three layers, laid like cut paper: a frame of the biome's material the
  /// full size of the plot, a soft shadow, and a slightly smaller sheet of soil
  /// laid on top of it, lifted a little so the shadow shows along its lower
  /// edges. That is the same layering every plant is cut with, which is what
  /// keeps the ground from looking like a diagram under paper plants.
  ///
  /// Two tiles rather than one tinted two ways, because they differ in more
  /// than colour. Bare soil is unworked ground — the same cut, paler and dry,
  /// with two furrows pressed into it — so that a newly unlocked plot reads as
  /// somewhere a plant *could* go rather than as a plant that failed to draw.
  ///
  /// **Both tiles are opaque.** Bare soil used to be a faint sheet, which let
  /// whatever was behind it through: over `GardenBackdrop`'s green hills that
  /// mixed to a murky olive, and an empty garden — the first screen a new user
  /// sees — was a field of it (PRD v2.3). Paleness, not transparency, is what
  /// says "unplanted" now, and it says the same over any sky or hill.
  ///
  /// **The soil is soil and the frame is [decor]**, which is REQ-034's "soil
  /// tiles and decor" at the scale a plot has: the ground is earth, and the
  /// thing bounding it is the material this biome is built from — Zen's stone,
  /// the greenhouse's teak, the meadow's fence wood. It is the one part of a
  /// plot that does not move with the season, so a January meadow still reads
  /// as a meadow rather than as frost on something. REQ-040's objects are cut
  /// from the same material, which is why a lantern belongs to the plot it is
  /// standing on.
  static void _paintSoil(
    Canvas canvas,
    Rect cell,
    Color soil,
    Color decor, {
    required bool planted,
  }) {
    final frame = planted ? decor : Color.lerp(decor, _paper, _barePaleness)!;
    final ground = planted ? soil : Color.lerp(soil, _paper, _barePaleness)!;

    canvas.drawPath(
      _cutDiamond(cell, 1, Offset.zero),
      Paint()..color = frame,
    );
    canvas.drawPath(
      _cutDiamond(cell, 0.84, Offset(0, cell.height * 0.05)),
      Paint()
        ..color = Color.lerp(decor, const Color(0xFF000000), 0.45)!
            .withValues(alpha: planted ? 0.45 : 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell.height * 0.02),
    );
    final sheet = _cutDiamond(cell, 0.84, Offset(0, -cell.height * 0.01));
    canvas.drawPath(sheet, Paint()..color = ground);
    if (planted) return;

    // Two furrows across the bare sheet, along the diamond's long axis: ground
    // turned over and waiting, drawn in the soil's own colour.
    final furrow = Paint()
      ..color = soil.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = cell.height * 0.035;
    final c = sheet.getBounds().center;
    final reach = cell.width * 0.2;
    for (final dy in [-cell.height * 0.09, cell.height * 0.09]) {
      canvas.drawLine(
        Offset(c.dx - reach, c.dy + dy),
        Offset(c.dx + reach, c.dy + dy),
        furrow,
      );
    }
  }

  /// The pale, dry paper bare soil is lightened toward.
  static const Color _paper = Palette.surfaceLight;

  /// How far toward [_paper] bare soil and its frame are lightened.
  static const double _barePaleness = 0.3;

  /// A diamond [scale] the size of [cell], moved by [shift], whose edges
  /// wander a little as a scissor cut does.
  ///
  /// The wander is fixed rather than random: the two tiles are baked once and
  /// drawn at every plot, so every plot is the same cut.
  static Path _cutDiamond(Rect cell, double scale, Offset shift) {
    final c = cell.center + shift;
    final hx = cell.width / 2 * scale, hy = cell.height / 2 * scale;
    // Corner, then the middle of the edge after it, round the diamond. The
    // middles are pushed in or out by a few per cent.
    const nudges = [0.02, -0.025, 0.015, -0.02];
    final corners = [
      Offset(c.dx, c.dy - hy),
      Offset(c.dx + hx, c.dy),
      Offset(c.dx, c.dy + hy),
      Offset(c.dx - hx, c.dy),
    ];
    final path = Path()..moveTo(corners[0].dx, corners[0].dy);
    for (var i = 0; i < 4; i++) {
      final from = corners[i];
      final to = corners[(i + 1) % 4];
      final middle = Offset.lerp(from, to, 0.5)!;
      final outward = (middle - c) / (middle - c).distance;
      final bent = middle + outward * nudges[i] * cell.width * scale;
      path
        ..lineTo(bent.dx, bent.dy)
        ..lineTo(to.dx, to.dy);
    }
    return path..close();
  }
}

/// Everything an atlas is baked from, as one comparable value.
///
/// The colours are the theme's, so a phone going dark, ticket 14's seasons and
/// ticket 19's themes all arrive here as a different recipe and a rebake.
/// Comparing recipes is how the garden avoids rebaking a texture on a rebuild
/// that changed none of them.
@immutable
final class GardenAtlasRecipe {
  const GardenAtlasRecipe({
    required this.registry,
    required this.palettes,
    required this.decorRegistry,
    required this.decorPalette,
    required this.soil,
    required this.decor,
  });

  /// Where the plant pictures come from. Ticket 23 changes this one and the
  /// decor registry beside it, and nothing else.
  final PlantSpriteRegistry registry;

  /// The colours each species is drawn in.
  final Map<PlantSpecies, PlantPalette> palettes;

  /// Where REQ-040's objects come from.
  final DecorSpriteRegistry decorRegistry;

  /// The colours all four of them are drawn in.
  ///
  /// One palette for the four, where a plant gets one per species: a species is
  /// what makes a basil a different green from a mint, and a bench is made of
  /// the same wood as the fence. What varies between the four objects is their
  /// shape and how much of the palette they spend, which is the sprite's
  /// business and not this one's.
  final DecorPalette decorPalette;

  /// The colour of the ground.
  final Color soil;

  /// The material a plot is edged in: REQ-034's biome, as the one colour in
  /// here a season leaves alone.
  final Color decor;

  @override
  bool operator ==(Object other) =>
      other is GardenAtlasRecipe &&
      other.registry == registry &&
      other.decorRegistry == decorRegistry &&
      other.decorPalette == decorPalette &&
      other.soil == soil &&
      other.decor == decor &&
      mapEquals(other.palettes, palettes);

  @override
  int get hashCode => Object.hash(
        registry,
        decorRegistry,
        decorPalette,
        soil,
        decor,
        Object.hashAll([
          for (final species in PlantSpecies.values) palettes[species],
        ]),
      );
}
