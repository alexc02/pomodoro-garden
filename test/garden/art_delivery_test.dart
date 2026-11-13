import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/garden/art_bundle.dart';

// Checks on the delivered art itself (art_bundle_test.dart covers the
// pipeline). These catch problems that would otherwise only show up on a
// device:
//
// - footprint out of sync with its drawing (silently breaks hit-testing)
// - art not anchored at the bottom middle of its square (plants float)
// - thresholded 1-bit alpha (jagged edges on 3x screens)
// - stages that shrink or drift between steps
//
// Can't tell whether the drawings actually look good; that needs eyes on a
// phone.

/// Alpha channel of one drawing. One byte per pixel keeps scanning ~78
/// 512px images cheap.
final class _Silhouette {
  _Silhouette(this.width, this.height, this._alpha);

  final int width;
  final int height;
  final Uint8List _alpha;

  static Future<_Silhouette> of(ui.Image image) async {
    final data = await image.toByteData();
    final rgba = data!.buffer.asUint8List();
    final alpha = Uint8List(image.width * image.height);
    for (var i = 0; i < alpha.length; i++) {
      alpha[i] = rgba[i * 4 + 3];
    }
    return _Silhouette(image.width, image.height, alpha);
  }

  int alphaAt(int x, int y) => _alpha[y * width + x];

  bool inkedAt(int x, int y) => alphaAt(x, y) != 0;

  int get inked => _alpha.where((it) => it != 0).length;

  /// Tight bounds of the ink as fractions of the image, i.e. what the
  /// manifest's footprint should be.
  ui.Rect get bounds {
    var left = width, top = height, right = -1, bottom = -1;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!inkedAt(x, y)) continue;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    if (right < 0) return ui.Rect.zero;

    // Right and bottom are exclusive: a pixel at x = 0 spans [0, 1).
    return ui.Rect.fromLTRB(
      left / width,
      top / height,
      (right + 1) / width,
      (bottom + 1) / height,
    );
  }

  /// Inked pixels with at least one non-inked neighbour.
  int get edgePixels {
    var count = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!inkedAt(x, y)) continue;
        if (x == 0 ||
            y == 0 ||
            x == width - 1 ||
            y == height - 1 ||
            !inkedAt(x - 1, y) ||
            !inkedAt(x + 1, y) ||
            !inkedAt(x, y - 1) ||
            !inkedAt(x, y + 1)) {
          count++;
        }
      }
    }
    return count;
  }

  /// Pixels that are neither fully transparent nor fully opaque. Zero means
  /// the alpha was thresholded on export.
  int get partial => _alpha.where((it) => it != 0 && it != 255).length;
}

typedef _Delivered = ({String path, ArtEntry entry, _Silhouette art});

void main() {
  // Plain test()s don't get a binding for free; asset access needs one.
  TestWidgetsFlutterBinding.ensureInitialized();

  late ArtManifest manifest;
  late Map<String, ui.Image> images;
  late List<_Delivered> plants;
  late List<_Delivered> decor;

  setUpAll(() async {
    manifest = ArtManifest.parse(
      await rootBundle.loadString(ArtBundle.manifestAsset),
    );

    images = {};
    for (final path in manifest.imagePaths) {
      images[path] = await _decode(path);
    }

    final silhouettes = <String, _Silhouette>{};
    for (final entry in images.entries) {
      silhouettes[entry.key] = await _Silhouette.of(entry.value);
    }

    _Delivered delivered(ArtEntry entry) => (
          path: entry.art,
          entry: entry,
          art: silhouettes[entry.art]!,
        );

    plants = [for (final entry in manifest.plants.values) delivered(entry)];
    decor = [for (final entry in manifest.decor.values) delivered(entry)];
  });

  tearDownAll(() {
    for (final image in images.values) {
      image.dispose();
    }
  });

  group('every drawing', () {
    test('is square with a same-size mask', () {
      // The mask is sampled in the drawing's coordinates, so different sizes
      // would misalign the tint. Square because both renderers draw into square
      // cells.
      for (final it in [...plants, ...decor]) {
        expect(
          it.art.width,
          it.art.height,
          reason: '${it.path} is ${it.art.width}×${it.art.height}, not square',
        );

        final mask = it.entry.roles;
        if (mask == null) continue;
        expect(
          [images[mask]!.width, images[mask]!.height],
          [it.art.width, it.art.height],
          reason: '${it.path} and its mask are different sizes',
        );
      }
    });

    test('is at least the largest draw size', () {
      // GardenAtlas uses 192px cells and the timer draws 88pt (264px at 3x).
      // Smaller art gets magnified and goes soft.
      for (final it in [...plants, ...decor]) {
        expect(
          it.art.width,
          greaterThanOrEqualTo(_minimumSide),
          reason: '${it.path} is ${it.art.width} px, below the $_minimumSide '
              'the timer screen asks for at 3×',
        );
      }
    });

    test('has real transparency', () {
      // Art exported onto white would show as a white card behind the plant.
      for (final it in [...plants, ...decor]) {
        expect(
          it.art.inked,
          lessThan(it.art.width * it.art.height),
          reason: '${it.path} is opaque to its corners: exported onto a matte',
        );
      }
    });

    test('alpha is not thresholded', () {
      // Jagged edges mean 1-bit alpha. Measured against the perimeter so it
      // scales from seed to oak.
      for (final it in [...plants, ...decor]) {
        final edge = it.art.edgePixels;
        expect(
          it.art.partial,
          greaterThan(edge ~/ 2),
          reason: '${it.path} has ${it.art.partial} partly-transparent pixels '
              'against an edge of $edge: its alpha channel has been '
              'thresholded, which is what a jagged edge is',
        );
      }
    });

    test('matches its manifest footprint', () {
      // The footprint is carried, not computed (see ArtManifest), so nothing at
      // runtime would notice a wrong one.
      for (final it in [...plants, ...decor]) {
        final measured = it.art.bounds;
        final claimed = it.entry.footprint;

        for (final (name, from, to) in [
          ('left', claimed.left, measured.left),
          ('top', claimed.top, measured.top),
          ('right', claimed.right, measured.right),
          ('bottom', claimed.bottom, measured.bottom),
        ]) {
          expect(
            from,
            closeTo(to, _footprintTolerance),
            reason: '${it.path} claims a $name edge of '
                '${from.toStringAsFixed(4)} and draws one at '
                '${to.toStringAsFixed(4)}',
          );
        }
      }
    });
  });

  group('every plant', () {
    test('sits on the bottom edge, centred', () {
      // Both renderers anchor a plant at the bottom middle of its cell
      // (GardenPainter's RSTransform, PlantPainter's bounds). Art centred in
      // its box would float.
      for (final it in plants) {
        final bounds = it.art.bounds;

        expect(
          bounds.bottom,
          greaterThan(1 - _standingTolerance),
          reason: '${it.path} stops at ${bounds.bottom.toStringAsFixed(3)} of '
              'its box: it floats rather than standing on the bottom edge',
        );
        expect(
          bounds.center.dx,
          closeTo(0.5, _centringTolerance),
          reason: '${it.path} is centred on '
              '${bounds.center.dx.toStringAsFixed(3)} rather than on 0.5',
        );
      }
    });

    test('has a role mask', () {
      // Without a mask the plant keeps its own colours, ignoring season,
      // theme and species.
      for (final it in plants) {
        expect(
          it.entry.roles,
          isNotNull,
          reason: '${it.path} ships without a role mask, so the palette cannot '
              'reach it',
        );
      }
    });
  });

  group('growth', () {
    test('each stage covers more than the last', () {
      // Every step, not just seed vs mature. A smaller stage would visibly
      // shrink mid-session.
      for (final form in PlantForm.values) {
        final areas = [
          for (final stage in _growing)
            _plant(manifest, form, stage, plants).art.inked,
        ];

        for (var i = 1; i < areas.length; i++) {
          expect(
            areas[i],
            greaterThan(areas[i - 1]),
            reason: '${form.name} covers less at ${_growing[i].name} '
                'than at ${_growing[i - 1].name}: it shrinks',
          );
        }
      }
    });

    test('never gets narrower or shorter', () {
      // Area growing while the bounding box shrinks means the stage jumped.
      for (final form in PlantForm.values) {
        final boxes = [
          for (final stage in _growing)
            _plant(manifest, form, stage, plants).art.bounds,
        ];

        for (var i = 1; i < boxes.length; i++) {
          expect(
            boxes[i].width,
            greaterThanOrEqualTo(boxes[i - 1].width - _growthTolerance),
            reason: '${form.name} is narrower at ${_growing[i].name} than at '
                '${_growing[i - 1].name}',
          );
          expect(
            boxes[i].height,
            greaterThanOrEqualTo(boxes[i - 1].height - _growthTolerance),
            reason: '${form.name} is shorter at ${_growing[i].name} than at '
                '${_growing[i - 1].name}',
          );
        }
      }
    });

    test('seed sits on the soil', () {
      // A seed sits in the ground, so it should be in the bottom of its box.
      for (final form in PlantForm.values) {
        final seed =
            _plant(manifest, form, GrowthStage.seed, plants).art.bounds;
        expect(
          seed.top,
          greaterThan(0.5),
          reason: '${form.name}\'s seed reaches into the top half of its box: '
              'it is drawn as a plant rather than as something in the soil',
        );
      }
    });

    test('does not drift between stages', () {
      // Checks movement between consecutive stages, not absolute position.
      // Small drift per step would look like the plant hopping sideways.
      for (final form in PlantForm.values) {
        final centres = [
          for (final stage in GrowthStage.values)
            _plant(manifest, form, stage, plants).art.bounds.center.dx,
        ];

        for (var i = 1; i < centres.length; i++) {
          expect(
            centres[i],
            closeTo(centres[i - 1], _driftTolerance),
            reason: '${form.name} moves sideways between '
                '${GrowthStage.values[i - 1].name} and '
                '${GrowthStage.values[i].name}: '
                '${centres[i - 1].toStringAsFixed(3)} → '
                '${centres[i].toStringAsFixed(3)}',
          );
        }
      }
    });
  });

  group('whole set', () {
    test('fits the size budget', () async {
      // The release binary size needs a real build (scripts/profile.sh --size);
      // this checks the art's share of it.
      var bytes = 0;
      for (final path in manifest.imagePaths) {
        bytes += (await rootBundle.load(path)).lengthInBytes;
      }

      final megabytes = bytes / (1024 * 1024);
      debugPrint(
        'art delivery | ${manifest.imagePaths.length} files, '
        '${megabytes.toStringAsFixed(2)} MB of $_artBudgetMegabytes MB',
      );

      expect(
        megabytes,
        lessThan(_artBudgetMegabytes),
        reason: 'art set alone would use up the 50 MB budget headroom',
      );
    });
  });
}

/// Stages where a plant only gets bigger. Seed is excluded: it's a bean on
/// the soil, and the sprout is narrower than it in every type. The seed has
/// its own check below.
const List<GrowthStage> _growing = [
  GrowthStage.sprout,
  GrowthStage.young,
  GrowthStage.maturing,
  GrowthStage.mature,
];

/// Timer draws plants at 88pt, 264px on a 3x phone; that's the largest use.
/// The garden atlas cell is 192.
const int _minimumSide = 264;

/// About 1.5px at 512, the width of the anti-aliased fringe.
const double _footprintTolerance = 0.003;

/// 5px at 512.
const double _standingTolerance = 0.01;

/// Generous: a leaning wildflower is fine. Catches art aligned to the wrong
/// edge.
const double _centringTolerance = 0.08;

/// Same anti-aliasing slack as [_footprintTolerance].
const double _growthTolerance = 0.005;

/// Max centre movement between stages, 10px at 512. Tighter than
/// [_centringTolerance] since it's the same plant on the same plot.
const double _driftTolerance = 0.02;

/// Android release is 29.3 MB of a 50 MB budget (stand-in art 0.36 MB).
/// This is the headroom minus a margin.
const double _artBudgetMegabytes = 16;

_Delivered _plant(
  ArtManifest manifest,
  PlantForm form,
  GrowthStage stage,
  List<_Delivered> plants,
) {
  final entry = manifest.plants[(form, stage)]!;
  return plants.firstWhere((it) => it.path == entry.art);
}

Future<ui.Image> _decode(String path) async {
  final data = await rootBundle.load(path);
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  final codec = await ui.instantiateImageCodecWithSize(buffer);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}
