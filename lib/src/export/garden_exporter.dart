import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../garden/garden_atlas.dart';
import '../garden/garden_painter.dart';
import '../garden/garden_projection.dart';

/// An exported garden image.
@immutable
final class GardenExport {
  const GardenExport({
    required this.png,
    required this.width,
    required this.height,
  });

  /// PNG: flat colour compresses well losslessly and badly with JPEG.
  final Uint8List png;

  /// In pixels.
  final int width;
  final int height;

  /// Fixed name; the platform handles duplicates.
  String get filename => 'pip-garden.png';
}

/// Renders the whole garden to an image, independent of the on-screen camera
/// and without any chrome.
///
/// Uses the same [GardenPainter] as the screen with its own projection, so
/// anything the painter draws shows up in exports for free. Theme and season
/// come in through the atlas and `sky`; this class doesn't know about either.
abstract final class GardenExporter {
  /// Sky around the garden, in logical units, so it doesn't look cropped.
  static const double margin = 48;

  /// Target long edge in pixels. Well above phone resolution, well below GPU
  /// texture limits.
  static const double targetLongEdge = 2048;

  /// Past this ratio we'd just be upscaling atlas sprites, so small gardens
  /// export smaller. Raise [GardenAtlas.cellWidth] to raise it.
  static final double maximumPixelRatio =
      GardenAtlas.cellWidth / GardenProjection.spriteSide;

  /// Hard cap on pixel count. RGBA while encoding, so ~64 MB worst case; a
  /// 200-plant garden is about a fifth of that.
  static const int maximumPixels = 16000000;

  /// Always scale 1: resolution is handled by the raster, so the user zoom
  /// clamps don't apply.
  static GardenProjection projectionFor(GardenLayout layout) {
    final bounds = const GardenProjection().boundsOf(layout.plots);
    return GardenProjection(
      pan: Offset(margin - bounds.left, margin - bounds.top),
    );
  }

  /// Garden bounds plus [margin], in logical units.
  static Size sheetFor(GardenLayout layout) {
    final bounds = const GardenProjection().boundsOf(layout.plots);
    if (bounds.isEmpty) return const Size(margin * 2, margin * 2);
    return Size(bounds.width + margin * 2, bounds.height + margin * 2);
  }

  /// Pixels per logical unit for [sheet].
  static double pixelRatioFor(Size sheet) {
    final longEdge = math.max(sheet.width, sheet.height);
    if (longEdge <= 0) return 1;

    var ratio = math.min(targetLongEdge / longEdge, maximumPixelRatio);

    // Pixel cap goes last so it wins.
    final area = sheet.width * sheet.height;
    if (area * ratio * ratio > maximumPixels) {
      ratio = math.sqrt(maximumPixels / area);
    }
    return ratio;
  }

  /// Draws [layout] on [sky]. Uses async [Picture.toImage] so rasterising runs
  /// off the Dart thread and doesn't drop frames.
  ///
  /// Caller must dispose the image ([render] does).
  static Future<Image> rasterise({
    required GardenLayout layout,
    required GardenAtlas atlas,
    required Color sky,
  }) async {
    final sheet = sheetFor(layout);
    final ratio = pixelRatioFor(sheet);

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    // Only place that deals in pixels; everything else is logical units.
    canvas.scale(ratio);

    canvas.drawRect(Offset.zero & sheet, Paint()..color = sky);

    GardenPainter(
      layout: layout,
      projection: projectionFor(layout),
      atlas: atlas,
    ).paint(canvas, sheet);

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(
        (sheet.width * ratio).round(),
        (sheet.height * ratio).round(),
      );
    } finally {
      picture.dispose();
    }
  }

  /// [rasterise] plus PNG encoding.
  static Future<GardenExport> render({
    required GardenLayout layout,
    required GardenAtlas atlas,
    required Color sky,
  }) async {
    final image = await rasterise(layout: layout, atlas: atlas, sky: sky);

    try {
      final encoded = await image.toByteData(format: ImageByteFormat.png);
      if (encoded == null) {
        throw StateError('The garden was drawn but could not be encoded.');
      }

      return GardenExport(
        png: encoded.buffer.asUint8List(),
        width: image.width,
        height: image.height,
      );
    } finally {
      // Free the raw image now; the share sheet may stay open a while.
      image.dispose();
    }
  }
}
