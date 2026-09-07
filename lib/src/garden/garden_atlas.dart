import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../design/palette.dart';
import 'decor_sprite.dart';
import 'plant_sprite.dart';

/// Every picture the garden draws, baked into one texture.
///
/// One image and one `drawAtlas` per frame is what makes 200 plants cheap.
/// Plants and decor share the texture because a second atlas means a second
/// batch, and then the depth sort between a bench and a tree breaks.
///
/// Cells are filled by letting each registry sprite paint itself once at bake
/// time, so swapping in decoded PNG sprites needs no change here. Colours are
/// baked per species since `drawAtlas` can only apply one tint and a plant has
/// three. Only [GrowthStage.mature] is baked: only finished plants reach the
/// garden.
final class GardenAtlas {
  /// Positional because named parameters can't be private.
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

  /// Soil tile width in texture pixels (tile is 2:1). Plant and decor cells
  /// are squares of this side. Big enough that max zoom still samples down.
  static const int cellWidth = 192;

  final Image _image;
  final Map<PlantSpecies, Rect> _plants;
  final Map<PlantSpecies, Rect> _footprints;
  final Map<DecorKind, Rect> _decor;
  final Map<DecorKind, Rect> _decorFootprints;

  final Rect emptySoil;

  /// Tile for an occupied plot (plant or decor).
  final Rect plantedSoil;

  /// The enchanted willow's halo, baked in a square cell with the same anchor
  /// as a plant so it can sit behind the willow in the same batch.
  final Rect glowHalo;

  /// The recipe this was baked from. Callers compare it to skip rebaking when
  /// nothing changed.
  final GardenAtlasRecipe signature;

  /// Total over [PlantSpecies].
  Rect rectFor(PlantSpecies species) => _plants[species]!;

  /// Total over [DecorKind].
  Rect rectForDecor(DecorKind kind) => _decor[kind]!;

  /// How much of its cell [species]'s picture fills, as fractions of the cell
  /// (`Rect.fromLTRB(0, 0, 1, 1)` is all of it).
  ///
  /// Hit-testing reads this instead of asking the registry, so the choice of
  /// sprite per cell is only made once, in [bake].
  Rect footprintFor(PlantSpecies species) => _footprints[species]!;

  /// Same as [footprintFor], for decor.
  Rect footprintForDecor(DecorKind kind) => _decorFootprints[kind]!;

  /// Side of a plant cell in texture pixels, for [RSTransform] scaling.
  double get plantCell => cellWidth.toDouble();

  /// Draws [rects] of this texture at [transforms] in one call. The only code
  /// that touches the image (see
  /// `test/garden/sprites_are_the_only_art_test.dart`).
  ///
  /// [colors] washes each quad (the golden shimmer). `drawAtlas` treats the
  /// colour as destination, so `dstATop` lays it over the picture inside its
  /// shape; transparent leaves a quad unchanged. Not `srcATop`: that keeps the
  /// colour's alpha and fades the whole garden (`garden_glow_test.dart` pins
  /// this).
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

  /// Medium filtering because the garden nearly always samples down (88px
  /// plot from a 192px cell); at low, a zoomed-out garden shimmers when moved.
  static final Paint _blit = Paint()..filterQuality = FilterQuality.medium;

  /// Releases the texture.
  void dispose() => _image.dispose();

  /// Bakes an atlas from [recipe]. Synchronous (`Picture.toImageSync`) so the
  /// garden never has a frame without a texture.
  static GardenAtlas bake(GardenAtlasRecipe recipe) {
    const species = PlantSpecies.values;
    const decor = DecorKind.values;
    // Plants, then decor, then one cell for the willow halo, in a roughly
    // square grid (wastes less texture and stays well under max texture
    // width).
    final cells = species.length + decor.length + 1;
    final columns = math.sqrt(cells).ceil();
    final rows = (cells / columns).ceil();

    const int pad = _padding;
    final sheetWidth = columns * (cellWidth + pad) + pad;
    // One extra row for the two soil tiles, which are half height.
    final soilTop = rows * (cellWidth + pad) + pad;
    final sheetHeight = soilTop + cellWidth ~/ 2 + pad;

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    Rect cellAt(int index) => Rect.fromLTWH(
          ((index % columns) * (cellWidth + pad) + pad).toDouble(),
          ((index ~/ columns) * (cellWidth + pad) + pad).toDouble(),
          cellWidth.toDouble(),
          cellWidth.toDouble(),
        );

    /// Footprint as fractions of the cell it was baked into (not a unit
    /// square), since some details like minimum stroke widths don't scale.
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

      // The only place that picks a plant's picture; rect and footprint
      // both come from this sprite.
      final sprite = recipe.registry
          .spriteFor(type: species[index].type, stage: GrowthStage.mature);
      final square = Rect.fromLTWH(0, 0, cell.width, cell.height);

      canvas.save();
      canvas.translate(cell.left, cell.top);
      // Sprites stand on the bottom edge, which matches the painter's
      // anchor.
      sprite.paint(canvas, square, recipe.palettes[species[index]]!);
      canvas.restore();

      footprints[species[index]] = fractionsOf(sprite.footprintIn(square), square);
    }

    final objects = <DecorKind, Rect>{};
    final decorFootprints = <DecorKind, Rect>{};
    for (var index = 0; index < decor.length; index++) {
      final cell = cellAt(species.length + index);
      objects[decor[index]] = cell;

      // Same square as a plant, so one anchor works for both.
      final sprite = recipe.decorRegistry.spriteFor(decor[index]);
      final square = Rect.fromLTWH(0, 0, cell.width, cell.height);

      canvas.save();
      canvas.translate(cell.left, cell.top);
      sprite.paint(canvas, square, recipe.decorPalette);
      canvas.restore();

      decorFootprints[decor[index]] =
          fractionsOf(sprite.footprintIn(square), square);
    }

    // Fades out well inside the cell so the edge never shows.
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

  /// Gap between cells so filtering can't bleed neighbours into an edge.
  static const int _padding = 2;

  /// One plot's ground: a cut-paper diamond filling [cell].
  ///
  /// Three layers: a frame in the biome's [decor] material, a soft shadow, and
  /// a slightly smaller, lifted sheet of soil. The frame ignores the season,
  /// so the biome still reads in winter.
  ///
  /// Bare soil is paler with two furrows, so an empty plot doesn't look like a
  /// plant that failed to draw. Both tiles are opaque: a translucent bare tile
  /// went murky olive over `GardenBackdrop`'s hills.
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

    // Two furrows along the long axis, in the soil colour.
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

  static const Color _paper = Palette.surfaceLight;

  /// How far toward [_paper] bare soil and its frame are lightened.
  static const double _barePaleness = 0.3;

  /// A diamond [scale] the size of [cell], moved by [shift], with slightly
  /// wobbly edges like a scissor cut. Fixed wobble, so every plot matches.
  static Path _cutDiamond(Rect cell, double scale, Offset shift) {
    final c = cell.center + shift;
    final hx = cell.width / 2 * scale, hy = cell.height / 2 * scale;
    // Each edge's midpoint is nudged in or out by a few percent.
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

/// Everything an atlas is baked from, as one comparable value. A dark-mode,
/// season or theme change arrives as a different recipe and a rebake.
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

  final PlantSpriteRegistry registry;

  final Map<PlantSpecies, PlantPalette> palettes;

  final DecorSpriteRegistry decorRegistry;

  /// One palette for all decor (unlike plants, which get one per species).
  final DecorPalette decorPalette;

  final Color soil;

  /// The plot frame material; the one colour the season doesn't touch.
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
