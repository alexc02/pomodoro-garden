import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'image_sprites.dart';

/// Every picture the app draws, decoded and ready to paint.
///
/// **This class is the answer to the question ticket 23's premise skips.** The
/// ticket says the art swap is "assets and registry entries only, no logic
/// modified", and that is nearly true — but not quite, and the gap is here.
/// [PlantSprite.paint] is synchronous and `GardenAtlas.bake` is synchronous
/// (`Picture.toImageSync`, so that the garden never has a frame with no texture
/// to draw). Decoding a PNG is not. Something therefore has to decode every
/// image *before* the first garden frame, and until this class there was
/// nowhere for that something to live.
///
/// So the art swap is assets, registry entries, **and one gate**. See
/// `ArtGate`, and `docs/art-pipeline.md` for the whole shape.
///
/// ## What it costs, and where
///
/// This runs once, at launch, on the path PRD §4.4 budgets at 1.5 seconds. The
/// decodes are issued together rather than in a loop, so the cost is roughly the
/// slowest image rather than the sum of all of them — but it is real, and it is
/// the single largest thing this app does before it can draw. The measurement is
/// in `docs/performance-record.md`.
///
/// Nothing is decoded twice and nothing is decoded lazily: a plant that appeared
/// for the first time three sessions in and had to decode itself would drop the
/// frame it appeared on, which on the timer screen is exactly the moment the user
/// is watching.
final class ArtBundle {
  const ArtBundle({required this.plants, required this.decor});

  /// Where a plant's picture comes from once this bundle is loaded.
  final ImagePlantSpriteRegistry plants;

  /// And an object's.
  final ImageDecorSpriteRegistry decor;

  /// Where the manifest lives. The art beside it is named *by* it, so this is
  /// the only asset path the app knows.
  static const String manifestAsset = 'assets/art/manifest.json';

  /// Reads the manifest, decodes everything it names, and checks that what came
  /// back covers every plant and every object.
  ///
  /// Throws [ArtBundleException] if the manifest is unreadable or incomplete.
  /// **Deliberately fatal rather than falling back to the placeholders**: art
  /// that is half-delivered is a garden with holes in it, and a silent fallback
  /// would ship that to a store looking like a style choice. The call site
  /// decides what to do about it — see `artBundleProvider`, which is where the
  /// decision to fall back for a *missing* bundle (as opposed to a broken one)
  /// is made and explained.
  static Future<ArtBundle> load(AssetBundle bundle) async {
    final manifest = ArtManifest.parse(
      await bundle.loadString(manifestAsset),
    );

    // Issued together: sixty-five sequential awaits would be sixty-five round
    // trips through the asset bundle, and they do not depend on each other.
    final images = <String, ui.Image>{};
    await Future.wait([
      for (final path in manifest.imagePaths)
        _decode(bundle, path).then((image) => images[path] = image),
    ]);

    ImageSpriteArt artFor(ArtEntry entry) => ImageSpriteArt(
          art: images[entry.art]!,
          roles: entry.roles == null ? null : images[entry.roles!],
          footprint: entry.footprint,
        );

    final plants = {
      for (final entry in manifest.plants.entries)
        entry.key: ImagePlantSprite(artFor(entry.value)),
    };
    final decor = {
      for (final entry in manifest.decor.entries)
        entry.key: ImageDecorSprite(artFor(entry.value), kind: entry.key),
    };

    // Totality, checked once here so that `spriteFor` can go on being a map
    // read with a `!` on it. A missing plant found at paint time is a crash in
    // the middle of a session; found here it is a build that does not ship.
    for (final type in PlantType.values) {
      for (final stage in GrowthStage.values) {
        if (!plants.containsKey((type, stage))) {
          throw ArtBundleException(
            'no art for ${type.name} at ${stage.name}',
          );
        }
      }
    }
    for (final kind in DecorKind.values) {
      if (!decor.containsKey(kind)) {
        throw ArtBundleException('no art for ${kind.name}');
      }
    }

    return ArtBundle(
      plants: ImagePlantSpriteRegistry(plants),
      decor: ImageDecorSpriteRegistry(decor),
    );
  }

  /// Releases every texture. Called when a bundle is replaced, which in the
  /// shipping app is never — the art outlives the process.
  void dispose() {
    for (final sprite in plants.sprites) {
      sprite.art.dispose();
    }
    for (final sprite in decor.sprites) {
      sprite.art.dispose();
    }
  }

  static Future<ui.Image> _decode(AssetBundle bundle, String path) async {
    final ByteData data;
    try {
      data = await bundle.load(path);
    } catch (error) {
      // Caught broadly on purpose. The asset bundle signals a path it does not
      // have with a `FlutterError`, which is an `Error` and not an `Exception`,
      // so `on Exception` lets exactly the commonest failure through. They all
      // mean the same thing to a caller — the art is not there — and none is
      // worth telling apart in a message that already names the file.
      throw ArtBundleException(
        '$path is named by the manifest and could not be read: $error',
      );
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final codec = await ui.instantiateImageCodecWithSize(buffer);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }
}

/// Something wrong with the art itself, as opposed to with the code that draws
/// it. Always a build-time mistake reaching runtime.
final class ArtBundleException implements Exception {
  const ArtBundleException(this.message);

  final String message;

  @override
  String toString() => 'ArtBundleException: $message';
}

/// One drawing in the manifest: where it is, what tints it, and how much of its
/// box it fills.
final class ArtEntry {
  const ArtEntry({
    required this.art,
    required this.footprint,
    this.roles,
  });

  /// The asset path of the drawing.
  final String art;

  /// The asset path of its role mask, or null for art the palette cannot reach.
  final String? roles;

  /// The tight bounds of the drawing's own ink, as fractions of its box.
  final Rect footprint;
}

/// What art there is, read from `assets/art/manifest.json`.
///
/// A manifest rather than a naming convention, for one reason that is worth the
/// file: **the footprints**. Ticket 12 hit-tests against how much of its box a
/// plant actually fills, and for a drawing that is the tight bounds of its own
/// non-transparent pixels — which is a scan of the alpha channel, sixty-five
/// times, on the launch path. Computed when the art is built and read from here
/// instead, it costs a JSON parse.
///
/// It also gives the delivery a shape that can be checked without a person
/// looking at it: `test/garden/art_delivery_test.dart` reads this and measures
/// every row against the file it names — including the footprint itself, which
/// is the one field nothing at runtime ever compares against the drawing.
final class ArtManifest {
  const ArtManifest({
    required this.plants,
    required this.decor,
  });

  final Map<(PlantType, GrowthStage), ArtEntry> plants;
  final Map<DecorKind, ArtEntry> decor;

  /// Every distinct image path the manifest names, drawings and masks together.
  Iterable<String> get imagePaths => {
        for (final entry in [...plants.values, ...decor.values]) ...[
          entry.art,
          ?entry.roles,
        ],
      };

  static ArtManifest parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw ArtBundleException('the manifest is not JSON: ${error.message}');
    }

    if (decoded is! Map<String, Object?>) {
      throw const ArtBundleException('the manifest is not an object');
    }

    final plants = <(PlantType, GrowthStage), ArtEntry>{};
    for (final row in _rows(decoded, 'plants')) {
      final type = _enumBy(PlantType.values, row, 'type', (it) => it.name);
      final stage = _enumBy(GrowthStage.values, row, 'stage', (it) => it.name);
      plants[(type, stage)] = _entry(row);
    }

    final decor = <DecorKind, ArtEntry>{};
    for (final row in _rows(decoded, 'decor')) {
      decor[_enumBy(DecorKind.values, row, 'kind', (it) => it.name)] =
          _entry(row);
    }

    return ArtManifest(plants: plants, decor: decor);
  }

  static List<Map<String, Object?>> _rows(
    Map<String, Object?> manifest,
    String key,
  ) {
    final rows = manifest[key];
    if (rows is! List) {
      throw ArtBundleException('the manifest has no "$key" list');
    }
    return [
      for (final row in rows)
        if (row is Map<String, Object?>)
          row
        else
          throw ArtBundleException('a "$key" row is not an object'),
    ];
  }

  static T _enumBy<T>(
    List<T> values,
    Map<String, Object?> row,
    String key,
    String Function(T) name,
  ) {
    final wanted = row[key];
    for (final value in values) {
      if (name(value) == wanted) return value;
    }
    throw ArtBundleException('"$wanted" is not a known $key');
  }

  static ArtEntry _entry(Map<String, Object?> row) {
    final art = row['art'];
    if (art is! String) {
      throw const ArtBundleException('a manifest row names no art');
    }

    final footprint = row['footprint'];
    if (footprint is! List || footprint.length != 4) {
      throw ArtBundleException(
        '$art has no footprint, or one that is not [left, top, right, bottom]',
      );
    }

    final roles = row['roles'];
    return ArtEntry(
      art: art,
      roles: roles is String ? roles : null,
      footprint: Rect.fromLTRB(
        (footprint[0]! as num).toDouble(),
        (footprint[1]! as num).toDouble(),
        (footprint[2]! as num).toDouble(),
        (footprint[3]! as num).toDouble(),
      ),
    );
  }
}
