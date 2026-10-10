import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/garden/art_bundle.dart';
import 'package:pomodoro_garden/src/garden/plant_sprite.dart';

/// Ticket 23's pipeline: art that arrives as files, decoded once, painted
/// through the seam ticket 04 built for it.
///
/// **The claim under test is the ticket's own premise** — that swapping the
/// placeholder shapes for real drawings is an asset change and not a rewrite.
/// Everything here goes through the same `PlantSpriteRegistry` the app has used
/// since ticket 04, so what these tests prove is that a decoded PNG satisfies
/// that interface as completely as a handful of circles does.
///
/// The art these run against is whatever is in `assets/art/`: since ticket 35,
/// the paper-cut set from `tool/generate_sprite_art.dart`. What is being checked
/// is the pipeline, and a pipeline cannot tell one drawing from another.

const PlantPalette _green = PlantPalette(
  foliage: Color(0xFF00FF00),
  bloom: Color(0xFF00FF00),
  soil: Color(0xFF00FF00),
);

const PlantPalette _red = PlantPalette(
  foliage: Color(0xFFFF0000),
  bloom: Color(0xFFFF0000),
  soil: Color(0xFFFF0000),
);

/// Paints [sprite] into a [side]-square and hands back its pixels, RGBA.
Future<Uint32List> _pixels(
  PlantSprite sprite,
  PlantPalette palette, {
  int side = 64,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  sprite.paint(
    canvas,
    ui.Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
    palette,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(side, side);
  picture.dispose();

  final data = await image.toByteData();
  image.dispose();
  return data!.buffer.asUint32List();
}

/// How many pixels of [pixels] are not fully transparent.
int _inked(Uint32List pixels) =>
    pixels.where((pixel) => (pixel >> 24) & 0xFF != 0).length;

/// A bundle serving exactly what it is given, and throwing for anything else —
/// which is what `rootBundle` does for an asset that is not there.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.entries);

  final Map<String, ByteData> entries;

  @override
  Future<ByteData> load(String key) async {
    final data = entries[key];
    if (data == null) throw FlutterError('no asset at $key');
    return data;
  }
}

ByteData _text(String value) =>
    ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));

void main() {
  // Asset access goes through the binding, and a file of plain `test`s does not
  // get one for free the way `testWidgets` does.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the manifest', () {
    test('reads a plant, its mask and its footprint', () {
      final manifest = ArtManifest.parse(jsonEncode({
        'plants': [
          {
            'type': 'herb',
            'stage': 'sprout',
            'art': 'a.png',
            'roles': 'a.roles.png',
            'footprint': [0.1, 0.2, 0.8, 1.0],
          },
        ],
        'decor': <Object?>[],
      }));

      final entry = manifest.plants[(PlantType.herb, GrowthStage.sprout)]!;
      expect(entry.art, 'a.png');
      expect(entry.roles, 'a.roles.png');
      expect(entry.footprint, const ui.Rect.fromLTRB(0.1, 0.2, 0.8, 1));
    });

    test('allows a drawing with no mask, which the palette cannot reach', () {
      final manifest = ArtManifest.parse(jsonEncode({
        'plants': <Object?>[],
        'decor': [
          {'kind': 'pond', 'art': 'p.png', 'footprint': [0, 0, 1, 1]},
        ],
      }));

      expect(manifest.decor[DecorKind.pond]!.roles, isNull);
    });

    test('names every image it points at, once', () {
      final manifest = ArtManifest.parse(jsonEncode({
        'plants': [
          {
            'type': 'herb',
            'stage': 'sprout',
            'art': 'a.png',
            'roles': 'shared.png',
            'footprint': [0, 0, 1, 1],
          },
          {
            'type': 'herb',
            'stage': 'young',
            'art': 'b.png',
            'roles': 'shared.png',
            'footprint': [0, 0, 1, 1],
          },
        ],
        'decor': <Object?>[],
      }));

      // A set, so a mask two drawings share is decoded once rather than twice.
      expect(manifest.imagePaths.toSet(), {'a.png', 'b.png', 'shared.png'});
      expect(manifest.imagePaths.length, 3);
    });

    test('refuses a row with no footprint rather than guessing one', () {
      // Guessing would mean the whole box, which is a hit-test that gives a
      // wildflower's empty sky to the finger meant for the tree behind it.
      expect(
        () => ArtManifest.parse(jsonEncode({
          'plants': [
            {'type': 'herb', 'stage': 'sprout', 'art': 'a.png'},
          ],
          'decor': <Object?>[],
        })),
        throwsA(isA<ArtBundleException>()),
      );
    });

    test('refuses a plant type it does not know', () {
      expect(
        () => ArtManifest.parse(jsonEncode({
          'plants': [
            {
              'type': 'triffid',
              'stage': 'sprout',
              'art': 'a.png',
              'footprint': [0, 0, 1, 1],
            },
          ],
          'decor': <Object?>[],
        })),
        throwsA(isA<ArtBundleException>()),
      );
    });

    test('refuses something that is not a manifest at all', () {
      expect(
        () => ArtManifest.parse('not json'),
        throwsA(isA<ArtBundleException>()),
      );
    });
  });

  group('loading a bundle', () {
    test('refuses an art set that is missing a plant', () async {
      // The case that matters most, and the reason this throws rather than
      // falling back: a half-delivered set is a garden with holes in it, and a
      // silent fallback would ship that looking like a style choice.
      final bundle = _FakeBundle({
        ArtBundle.manifestAsset: _text(jsonEncode({
          'plants': [
            {
              'type': 'herb',
              'stage': 'sprout',
              'art': 'a.png',
              'footprint': [0, 0, 1, 1],
            },
          ],
          'decor': <Object?>[],
        })),
        'a.png': await _onePixelPng(),
      });

      await expectLater(
        ArtBundle.load(bundle),
        throwsA(
          isA<ArtBundleException>().having(
            (it) => it.message,
            'message',
            contains('no art for'),
          ),
        ),
      );
    });

    test('refuses a manifest naming a file that is not there', () async {
      final bundle = _FakeBundle({
        ArtBundle.manifestAsset: _text(jsonEncode({
          'plants': [
            {
              'type': 'herb',
              'stage': 'sprout',
              'art': 'missing.png',
              'footprint': [0, 0, 1, 1],
            },
          ],
          'decor': <Object?>[],
        })),
      });

      await expectLater(
        ArtBundle.load(bundle),
        throwsA(
          isA<ArtBundleException>().having(
            (it) => it.message,
            'message',
            contains('missing.png'),
          ),
        ),
      );
    });
  });

  group('the art this build ships', () {
    late ArtBundle art;

    setUpAll(() async => art = await ArtBundle.load(rootBundle));
    tearDownAll(() => art.dispose());

    test('covers every plant type at every stage', () {
      // Totality, end to end, against the real asset bundle: thirty-five
      // combinations, none of which may fail to draw.
      for (final type in PlantType.values) {
        for (final stage in GrowthStage.values) {
          expect(
            () => art.plants.spriteFor(type: type, stage: stage),
            returnsNormally,
            reason: '${type.name} at ${stage.name} has no art',
          );
        }
      }
    });

    test('and every one of REQ-040\'s objects', () {
      for (final kind in DecorKind.values) {
        expect(() => art.decor.spriteFor(kind), returnsNormally);
      }
    });

    test('draws something for every one of them', () async {
      // Not just "a sprite came back" — a sprite that paints nothing is a
      // plant-shaped hole, and it would satisfy every other test here.
      for (final type in PlantType.values) {
        for (final stage in GrowthStage.values) {
          final pixels = await _pixels(
            art.plants.spriteFor(type: type, stage: stage),
            _green,
          );
          expect(
            _inked(pixels),
            greaterThan(0),
            reason: '${type.name} at ${stage.name} painted nothing',
          );
        }
      }
    });

    test('takes the palette, which is what the mask is for', () async {
      // The claim the whole two-image design exists to make good: a fixed
      // drawing still turns with the season, the theme and the species. If this
      // fails, thirty-five PNGs have just taken tickets 14 and 19 away.
      final sprite = art.plants.spriteFor(
        type: PlantType.largeTree,
        stage: GrowthStage.mature,
      );

      final green = await _pixels(sprite, _green);
      final red = await _pixels(sprite, _red);

      expect(green, isNot(red), reason: 'the palette did not reach the art');

      // And it is the *colour* that moved, not the shape: a tint that changed
      // which pixels were inked would be a different drawing, not a recolour.
      expect(_inked(green), _inked(red));
    });

    test('costs what it costs to decode, which is the launch budget', () async {
      // PRD §4.4 budgets 1.5 seconds from launch to a visible garden, and
      // `ArtGate` spends some of it before anything can be drawn. This is the
      // number, and it is recorded in `docs/performance-record.md`.
      //
      // Not asserted tightly: it is a debug-build host reading and the real art
      // will weigh roughly thirty times what the stand-ins do. The bound is
      // loose enough not to flake and tight enough that a decode which had
      // become serial — sixty-five round trips instead of one wait — would trip
      // it.
      final clock = Stopwatch()..start();
      final second = await ArtBundle.load(rootBundle);
      clock.stop();
      second.dispose();

      debugPrint(
        'art baseline | decoding ${PlantType.values.length * GrowthStage.values.length + DecorKind.values.length} '
        'sprites: ${clock.elapsedMilliseconds} ms',
      );
      expect(clock.elapsedMilliseconds, lessThan(1500));
    });

    test('fills the same box it says it fills', () {
      // The manifest's footprint against the sprite's own answer, scaled. This
      // is what ticket 12 hit-tests against.
      final sprite = art.plants.spriteFor(
        type: PlantType.wildflower,
        stage: GrowthStage.mature,
      );

      const box = ui.Rect.fromLTWH(100, 200, 80, 80);
      final footprint = sprite.footprintIn(box);

      expect(footprint.left, greaterThanOrEqualTo(box.left - 0.01));
      expect(footprint.right, lessThanOrEqualTo(box.right + 0.01));
      expect(footprint.width, greaterThan(0));
      expect(footprint.height, greaterThan(0));
    });

    test('grows: a mature plant fills more of its box than a seed', () async {
      // Ticket 23's sixth criterion, as far as arithmetic can take it. The eye
      // judges whether a silhouette *evolves*; what a test can say is that the
      // five stages are not the same picture and that they get bigger.
      for (final type in PlantType.values) {
        final inked = <int>[];
        final drawings = <String>{};

        for (final stage in GrowthStage.values) {
          final pixels = await _pixels(
            art.plants.spriteFor(type: type, stage: stage),
            _green,
            side: 128,
          );
          inked.add(_inked(pixels));
          drawings.add(_fingerprint(pixels));
        }

        expect(
          inked.last,
          greaterThan(inked.first),
          reason: '${type.name} does not end up bigger than it started',
        );

        // Compared as pictures rather than as areas: two stages can cover the
        // same number of pixels and still be different drawings, and a count
        // that happened to collide would fail this for no reason.
        expect(
          drawings,
          hasLength(GrowthStage.values.length),
          reason: '${type.name} draws the same picture at two stages — a '
              'growth the user cannot see happening',
        );
      }
    });
  });
}

/// A cheap identity for an image: enough to tell two drawings apart, and not
/// meant to survive anything adversarial.
String _fingerprint(Uint32List pixels) {
  var hash = 17;
  for (final pixel in pixels) {
    hash = (hash * 31 + pixel) & 0xFFFFFFFF;
  }
  return '$hash:${_inked(pixels)}';
}

/// The smallest possible valid PNG, for tests that only need *a* decodable
/// image.
Future<ByteData> _onePixelPng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 1, 1),
    ui.Paint()..color = const Color(0xFFFFFFFF),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(1, 1);
  picture.dispose();

  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!;
}
