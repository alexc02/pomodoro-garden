import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/export/garden_exporter.dart';
import 'package:pip_garden/src/garden/garden_atlas.dart';
import 'package:pip_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pip_garden/src/garden/plant_sprite.dart';

import '../support/decor_fixtures.dart';

/// REQ-035's image: the whole garden, at a resolution worth keeping, with
/// nothing of the app in it.
///
/// The unit under test is deliberately not a screen. An export is a [Picture]
/// built from a layout, an atlas and a projection fitted to the garden — no
/// widget tree, no camera, no `RepaintBoundary` — and that is what makes "the
/// export is not a screenshot of the viewport" a structural fact rather than a
/// thing to eyeball. `test/features/garden/export_flow_test.dart` drives the
/// two doors that call this.

final DateTime _anchor = DateTime.utc(2026, 8, 11, 9, 41);

const PlantPalette _palette = PlantPalette(
  foliage: Color(0xFF4CAF50),
  bloom: Color(0xFFFFC107),
  soil: Color(0xFF795548),
);

const Color _sky = Color(0xFFBFE3F5);

GardenAtlas _atlas() => GardenAtlas.bake(
      GardenAtlasRecipe(
        registry: const PlaceholderPlantSpriteRegistry(),
        palettes: {
          for (final species in PlantSpecies.values) species: _palette,
        },
        decorRegistry: testDecorRegistry,
        decorPalette: testDecorPalette,
        soil: const Color(0xFF795548),
        decor: const Color(0xFF9A9A92),
      ),
    );

Plant _plant(GardenPlot plot, {String id = 'plant'}) => Plant(
      id: id,
      sessionId: 'session-$id',
      type: PlantType.largeTree,
      species: PlantSpecies.oak,
      stage: GrowthStage.mature,
      plantedAt: _anchor,
      sessionDuration: const Duration(minutes: 90),
      plot: plot,
    );

/// A garden of [plants] plants, filling outwards from the middle as a real one
/// does.
GardenLayout _garden({required int plants, int decor = 0}) => GardenLayout.of(
      plants: [
        for (var n = 0; n < plants; n++)
          _plant(GardenPlots.inPlacementOrder[n], id: 'plant-$n'),
      ],
      decor: [
        for (var n = 0; n < decor; n++)
          testDecor(
            DecorKind.values[n % DecorKind.values.length],
            GardenPlots.inPlacementOrder[plants + n],
            id: 'decor-$n',
          ),
      ],
      // A garden of n plants is one n completed sessions grew. The plots it
      // has are whatever REQ-018 unlocked for that many, and never fewer than
      // the things standing in them — so the decor above always has ground.
      completedSessions: plants,
    );


/// Every pixel of [image], as RGBA.
Future<Uint32List> _pixels(Image image) async {
  final data = await image.toByteData();
  return data!.buffer.asUint32List();
}

void main() {
  late GardenAtlas atlas;

  setUp(() => atlas = _atlas());
  tearDown(() => atlas.dispose());

  group('the projection', () {
    test('fits the whole garden, whatever the user was looking at', () {
      // The criterion, as the only thing that could make it true: the
      // projection an export is drawn through is computed from the layout and
      // takes no camera at all. There is no argument to this call that a pan or
      // a zoom could arrive through.
      final garden = _garden(plants: 200);
      final sheet = GardenExporter.sheetFor(garden);
      final projection = GardenExporter.projectionFor(garden);

      for (final plot in garden.plots) {
        expect(
          projection.spriteBounds(plot),
          _within(Offset.zero & sheet),
          reason: 'plot (${plot.x}, ${plot.y}) fell off the sheet',
        );
      }
    });

    test('leaves a margin, so nothing is flush against an edge', () {
      final garden = _garden(plants: 200);
      final sheet = GardenExporter.sheetFor(garden);
      final projection = GardenExporter.projectionFor(garden);

      final drawn = projection.boundsOf(garden.plots);
      expect(drawn.left, closeTo(GardenExporter.margin, 0.01));
      expect(drawn.top, closeTo(GardenExporter.margin, 0.01));
      expect(sheet.width - drawn.right, closeTo(GardenExporter.margin, 0.01));
      expect(sheet.height - drawn.bottom, closeTo(GardenExporter.margin, 0.01));
    });

    test('a garden of twelve plots makes a smaller sheet than one of two '
        'hundred', () {
      // The export is the garden's own size rather than a fixed canvas: a new
      // user's twelve plots are not a postage stamp in the middle of an
      // otherwise empty 2048-pixel sky.
      final small = GardenExporter.sheetFor(_garden(plants: 0));
      final full = GardenExporter.sheetFor(_garden(plants: 200));

      expect(small.width, lessThan(full.width));
      expect(small.height, lessThan(full.height));
    });
  });

  group('the resolution', () {
    test('a full garden is rasterised well above its logical size', () {
      final sheet = GardenExporter.sheetFor(_garden(plants: 200));
      final ratio = GardenExporter.pixelRatioFor(sheet);

      expect(ratio, greaterThan(1.5));
      expect(
        math.max(sheet.width, sheet.height) * ratio,
        closeTo(GardenExporter.targetLongEdge, 1),
      );
    });

    test('and a small one is not magnified past what the atlas holds', () {
      // A twelve-plot garden could be blown up to the target long edge, and
      // the pixels it gained would be invented: the atlas bakes a plant at 192
      // and the sheet draws it at 88, so past this ratio the export is
      // upsampling a texture rather than rendering detail.
      final sheet = GardenExporter.sheetFor(_garden(plants: 0));

      expect(GardenExporter.pixelRatioFor(sheet),
          GardenExporter.maximumPixelRatio);
      // Which is to say: the cap is the one that binds here, not the target.
      expect(
        math.max(sheet.width, sheet.height) * GardenExporter.maximumPixelRatio,
        lessThan(GardenExporter.targetLongEdge),
      );
    });

    test('no garden can ask for more pixels than the ceiling allows', () {
      // Ticket 24's mid-range Android, as arithmetic rather than as a hope: an
      // RGBA buffer is four bytes a pixel, and this is the one number that
      // bounds how big the export's is.
      for (final plants in [0, 12, 60, 200]) {
        final sheet = GardenExporter.sheetFor(_garden(plants: plants));
        final ratio = GardenExporter.pixelRatioFor(sheet);
        final pixels = sheet.width * ratio * sheet.height * ratio;

        expect(pixels, lessThanOrEqualTo(GardenExporter.maximumPixels));
      }
    });
  });

  group('what is in the picture', () {
    test('the sky is the background, and there is no chrome over it', () async {
      // The top-left pixel is the corner an app bar would be in. What is there
      // is the garden's own sky — REQ-034's theme and REQ-019's season arrive
      // as this colour and as the atlas, and nothing else on the screen the
      // user tapped export from is in the image at all.
      final image = await GardenExporter.rasterise(
        layout: _garden(plants: 12),
        atlas: atlas,
        sky: _sky,
      );
      addTearDown(image.dispose);

      final pixels = await _pixels(image);
      expect(pixels.first, _rgba(_sky));
    });

    test('the plants and the decor are both drawn', () async {
      // Asserted as "the picture is not just sky": every quad the painter puts
      // down comes out of one walk, and `decor_in_the_garden_test.dart` is
      // where that walk is pinned quad by quad. What this adds is that the walk
      // reached a real image.
      final image = await GardenExporter.rasterise(
        layout: _garden(plants: 20, decor: 4),
        atlas: atlas,
        sky: _sky,
      );
      addTearDown(image.dispose);

      final pixels = await _pixels(image);
      final painted = pixels.where((pixel) => pixel != _rgba(_sky)).length;

      expect(painted, greaterThan(pixels.length ~/ 20));
    });

    test('the image is as big as the ratio says it is', () async {
      final garden = _garden(plants: 12);
      final sheet = GardenExporter.sheetFor(garden);
      final ratio = GardenExporter.pixelRatioFor(sheet);

      final image = await GardenExporter.rasterise(
        layout: garden,
        atlas: atlas,
        sky: _sky,
      );
      addTearDown(image.dispose);

      expect(image.width, (sheet.width * ratio).round());
      expect(image.height, (sheet.height * ratio).round());
    });
  });

  group('nothing of the app is in the picture', () {
    test('the corners are sky, so no mark was laid over the garden', () async {
      // An earlier draft put the app's name in the bottom-right corner of a
      // free user's export and sold a clean one. The app is free and every
      // export is clean, so the corner an isometric garden leaves emptiest is
      // the one thing that can be asserted about it: it is still sky. See
      // `docs/adr/0021-…`.
      final garden = _garden(plants: 30, decor: 3);
      final image = await GardenExporter.rasterise(
        layout: garden,
        atlas: atlas,
        sky: _sky,
      );
      addTearDown(image.dispose);

      final pixels = await _pixels(image);
      // The bottom-right corner, and a band in from it wide enough to hold the
      // wordmark that used to be there.
      for (var row = image.height - 40; row < image.height; row++) {
        for (var column = image.width - 200; column < image.width; column++) {
          expect(
            pixels[row * image.width + column],
            _rgba(_sky),
            reason: 'something is drawn at ($column, $row)',
          );
        }
      }
    });

    test('and two exports of one garden are the same picture', () async {
      // There is one kind of export, so rendering the same garden twice can
      // only produce the same bytes. What this pins is that nothing about the
      // *device* reaches the image any more.
      final garden = _garden(plants: 20, decor: 2);

      final first = await GardenExporter.render(
        layout: garden,
        atlas: atlas,
        sky: _sky,
      );
      final second = await GardenExporter.render(
        layout: garden,
        atlas: atlas,
        sky: _sky,
      );

      expect(first.png, second.png);
    });
  });

  group('the export it hands back', () {
    test('is a PNG that says how big it is', () async {
      final export = await GardenExporter.render(
        layout: _garden(plants: 12),
        atlas: atlas,
        sky: _sky,
      );

      // PNG's magic number. The share sheet and the photo library both go on
      // the bytes rather than on the extension.
      expect(export.png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(export.width, greaterThan(0));
      expect(export.height, greaterThan(0));
      expect(export.filename, endsWith('.png'));
    });

    test('a two-hundred-plant garden exports, and is not enormous', () async {
      // The ticket's mid-range Android, at the size it actually asks about: a
      // full garden, encoded, is a file somebody can put in a message.
      final export = await GardenExporter.render(
        layout: _garden(plants: 200),
        atlas: atlas,
        sky: _sky,
      );

      expect(
        export.width * export.height,
        lessThanOrEqualTo(GardenExporter.maximumPixels),
      );
      expect(export.png.length, lessThan(8 * 1024 * 1024));
    });
  });
}

/// The 32-bit RGBA word `toByteData` writes for [colour].
int _rgba(Color colour) {
  final a = (colour.a * 255).round();
  final r = (colour.r * 255).round();
  final g = (colour.g * 255).round();
  final b = (colour.b * 255).round();
  // Little-endian, which is what `asUint32List` reads the RGBA bytes back as.
  return (a << 24) | (b << 16) | (g << 8) | r;
}

/// Matches a [Rect] wholly inside [outer].
Matcher _within(Rect outer) => predicate<Rect>(
      (inner) =>
          inner.left >= outer.left - 0.01 &&
          inner.top >= outer.top - 0.01 &&
          inner.right <= outer.right + 0.01 &&
          inner.bottom <= outer.bottom + 0.01,
      'inside $outer',
    );
