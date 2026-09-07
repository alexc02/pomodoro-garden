import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Every plant on screen goes through PlantSpriteRegistry, so swapping the
// art means changing the registry and nothing else. No view code may name an
// image; enforced here because the violation would be one innocent line.
void main() {
  test('only the sprite registry names an image', () {
    final offenders = <String>[];

    for (final file in _dartFilesUnder('lib')) {
      if (_mayNameAnImage(file.path)) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Skip comments.
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (_soundAsset.hasMatch(lines[i])) continue;
        if (_imageApi.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Plant art must go through PlantSpriteRegistry, not be named by '
          'the widget that draws it. Add the image to the registry under '
          'lib/src/garden/ and ask for it by (type, stage).\n'
          '${offenders.join('\n')}',
    );
  });

  test('app looks sprites up via the registry', () {
    // The override point exists.
    final providers =
        File('lib/src/garden/plant_providers.dart').readAsStringSync();

    expect(providers, contains('plantSpriteRegistryProvider'));
    expect(providers, contains('PlaceholderPlantSpriteRegistry'));
  });

  test('decor uses its own registry', () {
    // Decor art sits behind its own registry (keyed by kind, where plants are
    // keyed by type and stage), so it's the same one-line swap.
    final providers =
        File('lib/src/garden/decor_providers.dart').readAsStringSync();

    expect(providers, contains('decorSpriteRegistryProvider'));
    expect(providers, contains('PlaceholderDecorSpriteRegistry'));
  });
}

/// Files allowed to know what a plant looks like.
///
/// garden_atlas.dart names no asset: it asks the registry for sprites, bakes
/// them into a texture and owns the drawAtlas. image_sprites.dart draws decoded
/// images but is reached through the registry and names no asset either; the
/// paths are in the manifest, read only by art_bundle.dart.
bool _mayNameAnImage(String path) =>
    path.contains('lib/src/garden/plant_sprite.dart') ||
    path.contains('lib/src/garden/placeholder_plant_sprites.dart') ||
    path.contains('lib/src/garden/image_sprites.dart') ||
    path.contains('lib/src/garden/garden_atlas.dart');

/// Every way Flutter can get a picture on screen. Deliberately broad: a
/// false positive is a one-line fix here.
final _imageApi = RegExp(
  r'\b('
  r'Image\.(asset|network|file|memory)'
  r'|(Asset|Network|File|Memory|ExactAsset|Resize)Image\s*\('
  r'|ImageProvider'
  r'|DecorationImage'
  r'|drawImage(Rect|Nine)?\s*\('
  r'|drawAtlas\s*\('
  r'|rootBundle\.load'
  r')',
);

/// Bundled assets that aren't pictures.
///
/// rootBundle.load is also how the end sounds are read (iOS needs them copied
/// out before a notification can play one). Matched by the sound's own names
/// rather than exempting the file, so a plant image there would still be
/// caught; that's why the local at the load call is endSoundFile. Exact names,
/// since a \bendSound prefix would also match endSoundPlayerProvider.
final _soundAsset = RegExp(r'\bendSoundFile\b|\bwindChime|\.wav\b');

Iterable<File> _dartFilesUnder(String directory) => Directory(directory)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));
