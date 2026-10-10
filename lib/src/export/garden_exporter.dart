import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../garden/garden_atlas.dart';
import '../garden/garden_painter.dart';
import '../garden/garden_projection.dart';

/// A finished picture of a garden: REQ-035's image, and what it is.
@immutable
final class GardenExport {
  const GardenExport({
    required this.png,
    required this.width,
    required this.height,
  });

  /// The encoded image. PNG rather than JPEG because a garden is flat colour
  /// over flat colour — the shape a lossy codec is worst at, and the one a
  /// lossless one compresses hardest.
  final Uint8List png;

  /// How big it is, in pixels.
  final int width;
  final int height;

  /// What to call the file when it reaches the platform.
  ///
  /// Fixed rather than stamped with a date: it is a suggestion the share sheet
  /// shows, and two exports on the same day are two files the platform names
  /// apart itself.
  String get filename => 'pomodoro-garden.png';
}

/// Draws the whole garden into an image. REQ-035.
///
/// **The export is not a screenshot, and this file is where that is decided.**
/// Nothing here can see the camera: [projectionFor] is computed from the
/// layout's own plots, so an export made while the user is zoomed into one
/// corner is the same image as one made from the opening view. There is no
/// parameter a pan could arrive through, no `RepaintBoundary` to capture and no
/// widget tree in the call at all — which is also how the chrome is excluded,
/// since an app bar and a nav bar are things the export never had rather than
/// things it crops away.
///
/// It is the same [GardenPainter] the screen draws with, at a different
/// projection. That is the whole trick, and it is what ticket 20 left standing:
/// the painter emits one batch holding every plot, every plant and every one of
/// REQ-040's objects, so there is no second list of things for an exporter to
/// remember and no way for the picture to fall out of step with the garden. A
/// feature that ever needs drawing in an export needs drawing in the painter.
///
/// **The season and the theme arrive as the atlas and the sky**, exactly as they
/// do on screen — the caller bakes the atlas from the skin's own recipe and
/// hands over the same sky the garden is drawn on. Nothing in here knows that
/// either a season or a biome exists.
abstract final class GardenExporter {
  /// How much sky is left around the garden, in logical units.
  ///
  /// A picture wants air: a garden whose outermost tree is flush against the
  /// edge reads as a crop of a bigger garden.
  static const double margin = 48;

  /// What the long edge of an export aims for, in pixels.
  ///
  /// "High resolution" as a number somebody can argue with. It clears a
  /// phone's own screen several times over — which is what makes an export
  /// worth keeping as a wallpaper rather than a screenshot — and it is well
  /// inside the texture size every GPU this app runs on will allocate.
  static const double targetLongEdge = 2048;

  /// The most a logical unit may be magnified into pixels.
  ///
  /// **Derived from the atlas rather than chosen, because the atlas is the
  /// limit.** A plant is baked into a cell of [GardenAtlas.cellWidth] pixels
  /// and drawn on a sheet at [GardenProjection.spriteSide] logical units, so at
  /// exactly this ratio an export samples the texture one to one. Past it,
  /// every extra pixel is interpolated from a neighbour — a bigger file of the
  /// same picture, slightly softer.
  ///
  /// So a new user's twelve plots make a smaller image than a full garden does,
  /// and that is the honest answer rather than a shortfall: the pixels
  /// [targetLongEdge] would have added are pixels nothing knows the colour of.
  /// Ticket 23's real art can raise this by raising [GardenAtlas.cellWidth],
  /// and nothing else here changes.
  static final double maximumPixelRatio =
      GardenAtlas.cellWidth / GardenProjection.spriteSide;

  /// The most pixels an export may be, whatever else the arithmetic says.
  ///
  /// Ticket 24's mid-range Android, as a ceiling rather than as a hope. The
  /// image is held as an RGBA buffer while it is encoded — four bytes a pixel —
  /// so this is a little over sixty megabytes at the worst moment, on a device
  /// whose whole process budget is a few hundred. Nothing this app can draw
  /// comes close: a two-hundred-plant garden lands around a fifth of it, and
  /// the ceiling is here for the case a later ticket makes the garden bigger
  /// without thinking about this file.
  static const int maximumPixels = 16000000;

  /// Where the garden sits on its sheet.
  ///
  /// At a scale of one, always: the resolution is a property of the raster and
  /// not of the projection, which keeps the zoom clamps
  /// [GardenProjection.minimumScale] and [GardenProjection.maximumScale] out of
  /// this — they bound what a *user* may do to the camera, and an export has no
  /// camera to bound.
  static GardenProjection projectionFor(GardenLayout layout) {
    final bounds = const GardenProjection().boundsOf(layout.plots);
    return GardenProjection(
      pan: Offset(margin - bounds.left, margin - bounds.top),
    );
  }

  /// How big the sheet is for [layout], in logical units: the garden and its
  /// margin, and nothing else.
  static Size sheetFor(GardenLayout layout) {
    final bounds = const GardenProjection().boundsOf(layout.plots);
    if (bounds.isEmpty) return const Size(margin * 2, margin * 2);
    return Size(bounds.width + margin * 2, bounds.height + margin * 2);
  }

  /// How many pixels a logical unit of a sheet of [sheet] is rasterised into.
  static double pixelRatioFor(Size sheet) {
    final longEdge = math.max(sheet.width, sheet.height);
    if (longEdge <= 0) return 1;

    var ratio = math.min(targetLongEdge / longEdge, maximumPixelRatio);

    // The ceiling, applied last so it wins over both of the above.
    final area = sheet.width * sheet.height;
    if (area * ratio * ratio > maximumPixels) {
      ratio = math.sqrt(maximumPixels / area);
    }
    return ratio;
  }

  /// Draws [layout] into an image, on [sky].
  ///
  /// Asynchronous through [Picture.toImage] rather than `toImageSync`, and that
  /// is the difference between a share sheet that opens and a frame that is
  /// dropped: the raster of a few million pixels happens on the engine's own
  /// thread and Dart is free while it does. The atlas's own bake is synchronous
  /// for the opposite reason — a garden with no texture has nothing to draw —
  /// and an export has a progress indicator to show while it waits.
  ///
  /// The caller owns the image and must dispose it. [render] does that itself.
  static Future<Image> rasterise({
    required GardenLayout layout,
    required GardenAtlas atlas,
    required Color sky,
  }) async {
    final sheet = sheetFor(layout);
    final ratio = pixelRatioFor(sheet);

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    // Everything below is drawn in logical units and this is the only place
    // that knows about pixels, so the picture is the same drawing at every
    // resolution rather than a different one per device.
    canvas.scale(ratio);

    // The sky first, over the whole sheet: REQ-034's background, and the thing
    // that makes an export a picture rather than a cut-out.
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

  /// [rasterise], encoded and described: the thing that goes to the share
  /// sheet.
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
      // Released as soon as the bytes exist rather than at the end of the
      // export: the PNG is a fraction of the buffer's size, and the share sheet
      // may be on screen for as long as the user is choosing where to send it.
      image.dispose();
    }
  }
}
