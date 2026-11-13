import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'image_sprites.dart';

/// Every picture the app draws, decoded and ready to paint.
///
/// Sprite painting and `GardenAtlas.bake` (`Picture.toImageSync`) are
/// synchronous but PNG decoding isn't, so everything is decoded up front
/// before the first garden frame. See `ArtGate` and `docs/art-pipeline.md`.
///
/// This is the biggest thing the app does before it can draw. Nothing is decoded lazily, since a plant
/// decoding itself mid-session would drop a frame on the timer screen.
final class ArtBundle {
  const ArtBundle({required this.plants, required this.decor});

  final ImagePlantSpriteRegistry plants;

  final ImageDecorSpriteRegistry decor;

  /// The only asset path the app hard-codes; all the art is named by it.
  static const String manifestAsset = 'assets/art/manifest.json';

  /// Reads the manifest, decodes everything it names, and checks every plant
  /// and decor kind is covered.
  ///
  /// Throws [ArtBundleException] on a broken or incomplete manifest rather
  /// than falling back, so a half-delivered art set can't ship. The fallback
  /// for a missing bundle lives in `artBundleProvider`.
  static Future<ArtBundle> load(AssetBundle bundle) async {
    final manifest = ArtManifest.parse(
      await bundle.loadString(manifestAsset),
    );

    // Decoded in parallel; they don't depend on each other.
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

    // Check totality here so `spriteFor` can stay a map read with `!`.
    for (final form in PlantForm.values) {
      for (final stage in GrowthStage.values) {
        if (!plants.containsKey((form, stage))) {
          throw ArtBundleException(
            'no art for ${form.name} at ${stage.name}',
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

  /// Releases every texture. Never called in the shipping app.
  void dispose() {
    // Collected first: forms can share a drawing, and an image disposes once.
    final images = <ui.Image>{
      for (final sprite in [...plants.sprites, ...decor.sprites]) ...[
        sprite.art,
        ?sprite.roles,
      ],
    };
    for (final image in images) {
      image.dispose();
    }
  }

  static Future<ui.Image> _decode(AssetBundle bundle, String path) async {
    final ByteData data;
    try {
      data = await bundle.load(path);
    } catch (error) {
      // Catch everything: a missing asset throws `FlutterError`, which is
      // an `Error`, not an `Exception`.
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

/// Something wrong with the art set itself (a build-time mistake that reached
/// runtime).
final class ArtBundleException implements Exception {
  const ArtBundleException(this.message);

  final String message;

  @override
  String toString() => 'ArtBundleException: $message';
}

/// One drawing in the manifest.
final class ArtEntry {
  const ArtEntry({
    required this.art,
    required this.footprint,
    this.roles,
  });

  final String art;

  /// The role mask's asset path, or null for art the palette doesn't tint.
  final String? roles;

  /// The tight bounds of the drawing's own ink, as fractions of its box.
  final Rect footprint;
}

/// The art set, read from `assets/art/manifest.json`.
///
/// Mainly exists to carry precomputed footprints (tight ink bounds), so launch
/// doesn't have to scan every image's alpha channel.
/// `test/garden/art_delivery_test.dart` checks every row against its file.
final class ArtManifest {
  const ArtManifest({
    required this.plants,
    required this.decor,
  });

  final Map<(PlantForm, GrowthStage), ArtEntry> plants;
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

    // Rows may share a drawing: forms of one type start from the same seed
    // and sprout, and [imagePaths] decodes each file once.
    final plants = <(PlantForm, GrowthStage), ArtEntry>{};
    for (final row in _rows(decoded, 'plants')) {
      final form = _enumBy(PlantForm.values, row, 'form', (it) => it.name);
      final stage = _enumBy(GrowthStage.values, row, 'stage', (it) => it.name);
      plants[(form, stage)] = _entry(row);
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
