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

// The export image. It's a Picture built from layout, atlas and a projection
// fitted to the garden, with no widget tree or camera, so it can't be a
// viewport screenshot. The UI flow is in
// test/features/garden/export_flow_test.dart.

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

/// [plants] plants filling outwards from the middle.
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
      // Plots come from the unlock rule for that many sessions, so the decor
      // always has ground.
      completedSessions: plants,
    );

Future<Uint32List> _pixels(Image image) async {
  final data = await image.toByteData();
  return data!.buffer.asUint32List();
}

void main() {
  late GardenAtlas atlas;

  setUp(() => atlas = _atlas());
  tearDown(() => atlas.dispose());

  group('the projection', () {
    test('fits the whole garden', () {
      // Computed from the layout alone; there's no camera argument at all.
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

    test('leaves a margin', () {
      final garden = _garden(plants: 200);
      final sheet = GardenExporter.sheetFor(garden);
      final projection = GardenExporter.projectionFor(garden);

      final drawn = projection.boundsOf(garden.plots);
      expect(drawn.left, closeTo(GardenExporter.margin, 0.01));
      expect(drawn.top, closeTo(GardenExporter.margin, 0.01));
      expect(sheet.width - drawn.right, closeTo(GardenExporter.margin, 0.01));
      expect(sheet.height - drawn.bottom, closeTo(GardenExporter.margin, 0.01));
    });

    test('small garden gives a smaller sheet', () {
      // Sized to the garden, not a fixed canvas.
      final small = GardenExporter.sheetFor(_garden(plants: 0));
      final full = GardenExporter.sheetFor(_garden(plants: 200));

      expect(small.width, lessThan(full.width));
      expect(small.height, lessThan(full.height));
    });
  });

  group('the resolution', () {
    test('full garden renders above logical size', () {
      final sheet = GardenExporter.sheetFor(_garden(plants: 200));
      final ratio = GardenExporter.pixelRatioFor(sheet);

      expect(ratio, greaterThan(1.5));
      expect(
        math.max(sheet.width, sheet.height) * ratio,
        closeTo(GardenExporter.targetLongEdge, 1),
      );
    });

    test('small garden is not upscaled past the atlas', () {
      // The atlas bakes plants at 192 and the sheet draws at 88, so scaling
      // past that ratio would just upsample the texture.
      final sheet = GardenExporter.sheetFor(_garden(plants: 0));

      expect(GardenExporter.pixelRatioFor(sheet),
          GardenExporter.maximumPixelRatio);
      // The cap binds here, not the target.
      expect(
        math.max(sheet.width, sheet.height) * GardenExporter.maximumPixelRatio,
        lessThan(GardenExporter.targetLongEdge),
      );
    });

    test('pixel count is capped', () {
      // RGBA is 4 bytes a pixel; this bounds the buffer on mid-range Android.
      for (final plants in [0, 12, 60, 200]) {
        final sheet = GardenExporter.sheetFor(_garden(plants: plants));
        final ratio = GardenExporter.pixelRatioFor(sheet);
        final pixels = sheet.width * ratio * sheet.height * ratio;

        expect(pixels, lessThanOrEqualTo(GardenExporter.maximumPixels));
      }
    });
  });

  group('contents', () {
    test('sky background, no chrome', () async {
      // Top-left is where an app bar would be. It should be the garden sky.
      final image = await GardenExporter.rasterise(
        layout: _garden(plants: 12),
        atlas: atlas,
        sky: _sky,
      );
      addTearDown(image.dispose);

      final pixels = await _pixels(image);
      expect(pixels.first, _rgba(_sky));
    });

    test('draws plants and decor', () async {
      // Just checks it isn't only sky; quad order is covered in
      // decor_in_the_garden_test.dart.
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

    test('image size matches the ratio', () async {
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

  group('no app chrome', () {
    test('no watermark in the corner', () async {
      // No watermark any more, so the emptiest corner should still be sky. See
      // ADR 0005
      final garden = _garden(plants: 30, decor: 3);
      final image = await GardenExporter.rasterise(
        layout: garden,
        atlas: atlas,
        sky: _sky,
      );
      addTearDown(image.dispose);

      final pixels = await _pixels(image);
      // Bottom-right band, wide enough for the old wordmark.
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

    test('same garden exports identically', () async {
      // Nothing device-specific reaches the image.
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

  group('result', () {
    test('is a PNG with its size', () async {
      final export = await GardenExporter.render(
        layout: _garden(plants: 12),
        atlas: atlas,
        sky: _sky,
      );

      // PNG magic number; share sheet and photo library check the bytes.
      expect(export.png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(export.width, greaterThan(0));
      expect(export.height, greaterThan(0));
      expect(export.filename, endsWith('.png'));
    });

    test('200-plant garden exports at a sane size', () async {
      // A full garden should be small enough to send in a message.
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

/// The 32-bit word toByteData writes for [colour].
int _rgba(Color colour) {
  final a = (colour.a * 255).round();
  final r = (colour.r * 255).round();
  final g = (colour.g * 255).round();
  final b = (colour.b * 255).round();
  // Little-endian, as asUint32List reads it.
  return (a << 24) | (b << 16) | (g << 8) | r;
}

Matcher _within(Rect outer) => predicate<Rect>(
      (inner) =>
          inner.left >= outer.left - 0.01 &&
          inner.top >= outer.top - 0.01 &&
          inner.right <= outer.right + 0.01 &&
          inner.bottom <= outer.bottom + 0.01,
      'inside $outer',
    );
