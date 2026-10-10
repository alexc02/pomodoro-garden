import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/garden/art_bundle.dart';

/// **Is this delivery any good?** — as far as arithmetic can answer it.
///
/// `art_bundle_test.dart` asks whether the *pipeline* works: does every plant
/// resolve, does the palette reach it, does it draw anything at all. It would
/// pass on thirty-five copies of the same smudge. This file is the other half,
/// and it exists because ticket 23's art is a delivery from outside this
/// repository: the day it lands, somebody has to say whether it was prepared
/// correctly, and *most of the ways it can be wrong are invisible until
/// production*.
///
/// The four that this catches, none of which any other test in the suite would:
///
/// - **A footprint that does not match its drawing.** The manifest carries the
///   tight bounds of each drawing's own ink because computing them at launch
///   costs the cold path (see `ArtManifest`). Carried numbers go stale — a
///   redraw with the old row still beside it, an exporter that rounds the wrong
///   way — and a stale footprint is ticket 12's hit-test quietly handing a
///   wildflower's empty sky to the finger meant for the tree behind it. Nothing
///   crashes and nothing looks wrong. This is the check that costs the launch
///   budget nothing and is the reason the field can be trusted.
/// - **Art that is not on the grid the renderers assume.** Both of them hang a
///   plant from the bottom middle of its square (`GardenPainter`'s anchor, and
///   `PlantPainter`'s). Art centred in its box instead, or floating above the
///   bottom edge, draws a garden of levitating plants — on a device, not here.
/// - **Alpha that has been thresholded.** Ticket 23's fifth criterion asks for
///   *no jagged edges on transparency*, and a jagged edge is what a 1-bit alpha
///   channel is. It is a checkbox in an export dialog, and it is invisible until
///   the art is magnified on a 3× screen.
/// - **A set that has stopped growing.** Ticket 23's sixth criterion asks that
///   the five stages read as continuous growth. The eye judges whether a
///   silhouette *evolves*; what arithmetic can say is that it never shrinks and
///   never moves off the spot it is rooted to.
///
/// It runs against whatever is in `assets/art/` — since ticket 35, the
/// paper-cut set from `tool/generate_sprite_art.dart`, which passed it
/// unchanged. That is the point: these are the delivery's acceptance criteria,
/// written down before the delivery, in the only form that does not need a
/// person to remember to look.
///
/// **What it still cannot answer** is whether the drawings are any good, whether
/// a watercolour survives being shrunk to a plot, and whether the twelve
/// skin/season combinations look right over them. Those need eyes and a phone,
/// and they are named as such in the ticket.

/// The alpha channel of one drawing, and the questions worth asking of it.
///
/// Alpha only: every check here is about *where the ink is*, and none is about
/// what colour it is. Holding one byte per pixel rather than four keeps a scan
/// over seventy-eight 512-squares cheap enough to do on every run of the suite.
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

  /// How many pixels carry any ink at all.
  int get inked => _alpha.where((it) => it != 0).length;

  /// The tight bounds of that ink, as fractions of the image — which is exactly
  /// what the manifest's `footprint` claims to be.
  ///
  /// Empty for a drawing with no ink in it, which `art_bundle_test.dart`
  /// already refuses.
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

    // Right and bottom are exclusive: a single inked pixel at x = 0 occupies
    // the span [0, 1), not the empty span [0, 0].
    return ui.Rect.fromLTRB(
      left / width,
      top / height,
      (right + 1) / width,
      (bottom + 1) / height,
    );
  }

  /// How many inked pixels sit on the silhouette's edge — inked, with at least
  /// one neighbour that is not.
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

  /// How many pixels are neither fully transparent nor fully opaque.
  ///
  /// The measure of whether the alpha channel was thresholded on export. A hard
  /// edge has none of these; an anti-aliased one has a ribbon of them a pixel
  /// wide all the way round; a watercolour has a great many more.
  int get partial => _alpha.where((it) => it != 0 && it != 255).length;
}

/// Every drawing the manifest names, decoded, with the row that named it.
typedef _Delivered = ({String path, ArtEntry entry, _Silhouette art});

void main() {
  // Asset access goes through the binding, and a file of plain `test`s does not
  // get one for free the way `testWidgets` does.
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

  group('every drawing in the delivery', () {
    test('is square, and its mask is the same size', () {
      // The mask is sampled in the drawing's own coordinates — `paintTinted`
      // stretches both into the same `bounds` — so a mask of a different shape
      // is a tint sliding off the art it is meant to be tinting. Square because
      // both renderers scale the drawing into a square cell, and art of another
      // aspect ratio arrives stretched.
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

    test('is drawn at least as large as anything ever draws it', () {
      // PRD §9.1: deliver at the highest density needed and downscale at build
      // time. `GardenAtlas` bakes into a 192-pixel cell and the timer screen
      // asks for 88 logical points, which on a 3× phone is 264 device pixels.
      // Art delivered below that is being magnified, which is where ticket 23's
      // fifth criterion — no visible softness on a high-DPI device — fails.
      for (final it in [...plants, ...decor]) {
        expect(
          it.art.width,
          greaterThanOrEqualTo(_minimumSide),
          reason: '${it.path} is ${it.art.width} px, below the $_minimumSide '
              'the timer screen asks for at 3×',
        );
      }
    });

    test('has real transparency rather than a matte', () {
      // A drawing exported onto white is a drawing with a white rectangle
      // behind it, and in a garden that is a plant standing in a card. It
      // survives every other test in the suite: it decodes, it draws, the
      // palette reaches it.
      for (final it in [...plants, ...decor]) {
        expect(
          it.art.inked,
          lessThan(it.art.width * it.art.height),
          reason: '${it.path} is opaque to its corners — exported onto a matte',
        );
      }
    });

    test('has an alpha channel that was not thresholded on export', () {
      // Ticket 23's fifth criterion: no jagged edges on transparency. A jagged
      // edge *is* a 1-bit alpha channel, and the two are the same bug. Measured
      // against the silhouette's own perimeter rather than as a flat count, so
      // it means the same thing for a seed as for an oak.
      for (final it in [...plants, ...decor]) {
        final edge = it.art.edgePixels;
        expect(
          it.art.partial,
          greaterThan(edge ~/ 2),
          reason: '${it.path} has ${it.art.partial} partly-transparent pixels '
              'against an edge of $edge — its alpha channel has been '
              'thresholded, which is what a jagged edge is',
        );
      }
    });

    test('fills exactly the box the manifest says it fills', () {
      // **The check this file exists for.** The footprint is carried rather
      // than computed (see `ArtManifest`), so nothing at runtime ever compares
      // it against the drawing — and a wrong one breaks ticket 12's hit-test
      // silently, in a way no screenshot shows.
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
    test('stands on the bottom edge of its square, centred', () {
      // Both renderers hang a plant from the bottom middle of its cell —
      // `GardenPainter` through its `RSTransform` anchor, `PlantPainter`
      // through the bounds it is handed — so this is the contract that decides
      // whether a garden stands on its soil or floats above it. Art centred in
      // its box instead is the commonest way for a delivery to be wrong, and
      // there is no test above this one that would notice.
      for (final it in plants) {
        final bounds = it.art.bounds;

        expect(
          bounds.bottom,
          greaterThan(1 - _standingTolerance),
          reason: '${it.path} stops at ${bounds.bottom.toStringAsFixed(3)} of '
              'its box — it floats rather than standing on the bottom edge',
        );
        expect(
          bounds.center.dx,
          closeTo(0.5, _centringTolerance),
          reason: '${it.path} is centred on '
              '${bounds.center.dx.toStringAsFixed(3)} rather than on 0.5',
        );
      }
    });

    test('has a role mask, so the season and the theme can reach it', () {
      // A mask is optional in the format and wrong for a plant: without one the
      // drawing keeps its own colours, which takes ticket 14's seasons, ticket
      // 19's themes and the difference between a basil and a mint away from it
      // — and takes them away for that plant only, so the garden turns in
      // October around one plant that does not.
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

  group('growth reads as growth', () {
    test('every stage covers more of its box than the one before it', () {
      // Ticket 23's sixth criterion, as far as arithmetic reaches.
      // `art_bundle_test.dart` checks that a mature plant is bigger than a
      // seed; this checks every step in between, which is where a delivery
      // actually goes wrong — one stage drawn smaller than the last is a plant
      // the user watches shrink mid-session.
      for (final type in PlantType.values) {
        final areas = [
          for (final stage in _growing)
            _plant(manifest, type, stage, plants).art.inked,
        ];

        for (var i = 1; i < areas.length; i++) {
          expect(
            areas[i],
            greaterThan(areas[i - 1]),
            reason: '${type.name} covers less at ${_growing[i].name} '
                'than at ${_growing[i - 1].name} — it shrinks',
          );
        }
      }
    });

    test('and never gets narrower or shorter on the way', () {
      // The other half of continuity, and the one that catches a stage drawn to
      // a different brief: a silhouette that keeps growing in area while its
      // bounding box collapses is a picture that jumped rather than grew.
      for (final type in PlantType.values) {
        final boxes = [
          for (final stage in _growing)
            _plant(manifest, type, stage, plants).art.bounds,
        ];

        for (var i = 1; i < boxes.length; i++) {
          expect(
            boxes[i].width,
            greaterThanOrEqualTo(boxes[i - 1].width - _growthTolerance),
            reason: '${type.name} is narrower at ${_growing[i].name} than at '
                '${_growing[i - 1].name}',
          );
          expect(
            boxes[i].height,
            greaterThanOrEqualTo(boxes[i - 1].height - _growthTolerance),
            reason: '${type.name} is shorter at ${_growing[i].name} than at '
                '${_growing[i - 1].name}',
          );
        }
      }
    });

    test('and the seed it came out of sits on the soil, not above it', () {
      // The step the two above deliberately exclude, checked for the thing that
      // is actually true of it: a seed is *in the ground*, so it sits in the
      // bottom of its box rather than anywhere up the stem.
      for (final type in PlantType.values) {
        final seed =
            _plant(manifest, type, GrowthStage.seed, plants).art.bounds;
        expect(
          seed.top,
          greaterThan(0.5),
          reason: '${type.name}\'s seed reaches into the top half of its box — '
              'it is drawn as a plant rather than as something in the soil',
        );
      }
    });

    test('stays rooted to the spot it started on', () {
      // A plant grows upward out of one point on its plot, so what matters
      // between two stages is not where the drawing sits in its box — the test
      // above already pins that against the centre line — but whether it *moved*
      // since the stage before. A set that drifts a little at each step is one
      // the user sees hop sideways as a session passes, and every frame of it
      // would pass an absolute check that this catches.
      for (final type in PlantType.values) {
        final centres = [
          for (final stage in GrowthStage.values)
            _plant(manifest, type, stage, plants).art.bounds.center.dx,
        ];

        for (var i = 1; i < centres.length; i++) {
          expect(
            centres[i],
            closeTo(centres[i - 1], _driftTolerance),
            reason: '${type.name} moves sideways between '
                '${GrowthStage.values[i - 1].name} and '
                '${GrowthStage.values[i].name}: '
                '${centres[i - 1].toStringAsFixed(3)} → '
                '${centres[i].toStringAsFixed(3)}',
          );
        }
      }
    });
  });

  group('the set as a whole', () {
    test('weighs less than the headroom the binary budget leaves it', () async {
      // Ticket 23's seventh criterion, in the only form this machine can take
      // it: the delivery's own weight, against what `docs/performance-record.md`
      // measured there was room for. The release binary itself needs a build
      // (`scripts/profile.sh --size`); this is the number that moves it, and it
      // is the one that changes by a factor of thirty when the watercolour
      // arrives.
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
        reason: 'the art set alone would spend the headroom the 50 MB budget '
            'has left — see docs/performance-record.md §6',
      );
    });
  });
}

/// The stages over which a plant only ever gets bigger — **which is not all
/// five of them.**
///
/// [GrowthStage.seed] is deliberately outside it, because a seed is not a small
/// plant: it is a bean lying on the soil, and the shoot that comes up out of it
/// is *narrower than it was* in every one of ticket 04's seven types and by a
/// factor of four in the wildflower. Demanding monotone growth across that step
/// would be demanding that a sprout be drawn as wide as the seed casing it left
/// behind, which is a worse picture and not what ticket 23's sixth criterion is
/// asking for. What that criterion is asking for is that *the plant* evolve
/// rather than jump, and the plant starts at the sprout.
///
/// The seed keeps a check of its own — that it sits in the soil — below.
const List<GrowthStage> _growing = [
  GrowthStage.sprout,
  GrowthStage.young,
  GrowthStage.maturing,
  GrowthStage.mature,
];

/// The smallest side any drawing may be delivered at.
///
/// The timer screen draws a plant at 88 logical points, which on a 3× phone is
/// 264 device pixels, and that is the largest anything is ever drawn — the
/// garden's own ceiling is `GardenAtlas.cellWidth`, which is 192. Anything below
/// this is being magnified rather than downscaled.
const int _minimumSide = 264;

/// How far a carried footprint may sit from the ink it describes.
///
/// A pixel and a half at 512, which is the width of the anti-aliased fringe the
/// tight bounds are being taken through. Tighter than this measures the
/// exporter's rounding rather than the delivery.
const double _footprintTolerance = 0.003;

/// How far above the bottom edge a plant may stop and still count as standing
/// on it — five pixels at 512.
const double _standingTolerance = 0.01;

/// How far off centre a plant may be drawn. Generous on purpose: a wildflower
/// leaning out of one side of its square is a drawing, not a mistake, and what
/// this is looking for is art aligned to the wrong edge entirely.
const double _centringTolerance = 0.08;

/// Slack on "never narrower, never shorter", for the same anti-aliasing reason
/// [_footprintTolerance] has it.
const double _growthTolerance = 0.005;

/// How far a plant's centre may move between one stage and the next — ten
/// pixels at 512.
///
/// Much tighter than [_centringTolerance], and deliberately: a drawing may sit
/// a little off the centre line of its box and be right to, but it may not sit
/// somewhere *different* at each stage, because the five are the same plant on
/// the same plot a few minutes apart.
const double _driftTolerance = 0.02;

/// What the art set may weigh.
///
/// `docs/performance-record.md` §6 measures the Android release at 29.3 MB
/// against PRD §4.4's 50 MB, with the stand-ins' 0.36 MB inside that. This is
/// the headroom, less a margin for everything else that is still to grow — so a
/// delivery that would blow the binary budget fails here, where the fix is
/// compression, rather than in a store's upload dialog.
const double _artBudgetMegabytes = 16;

/// The delivered drawing for one plant.
_Delivered _plant(
  ArtManifest manifest,
  PlantType type,
  GrowthStage stage,
  List<_Delivered> plants,
) {
  final entry = manifest.plants[(type, stage)]!;
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
