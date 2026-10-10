import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ticket 04's most important promise, and the one a test has to keep because
/// nothing else can.
///
/// Every plant that reaches the screen resolves through
/// `PlantSpriteRegistry`. That is what lets ticket 23 replace all thirty
/// placeholder shapes with the real watercolour art by supplying a different
/// registry — "assets and registry entries only, no logic modified". The moment
/// one screen reaches past the registry for an image of its own, ticket 23 stops
/// being an asset swap and becomes a hunt through the widget tree.
///
/// So: no view code names an image. The rule is enforced here rather than left
/// to review, because the violation is a single plausible-looking line.
void main() {
  test('only the sprite registry names an image', () {
    final offenders = <String>[];

    for (final file in _dartFilesUnder('lib')) {
      if (_mayNameAnImage(file.path)) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Comments talk about images constantly; only code counts.
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
      reason: 'Plant art is reached through PlantSpriteRegistry, never named by '
          'the widget that draws it — that indirection is the whole of ticket '
          "04's contract with ticket 23. Add the image to the registry under "
          'lib/src/garden/ and ask for it by (type, stage).\n'
          '${offenders.join('\n')}',
    );
  });

  test('the registry is where the app looks a sprite up', () {
    // The other half: an override point that exists. Ticket 23 changes the one
    // line this asserts on and nothing else.
    final providers =
        File('lib/src/garden/plant_providers.dart').readAsStringSync();

    expect(providers, contains('plantSpriteRegistryProvider'));
    expect(providers, contains('PlaceholderPlantSpriteRegistry'));
  });

  test('REQ-040\'s decor is looked up the same way', () {
    // Ticket 20's art is behind the same seam and for the same reason: ticket
    // 23 replaces "decor art" along with the plants, and it should be the same
    // one-line swap. A second override point rather than a second *mechanism* —
    // a decor sprite is keyed by kind where a plant's is keyed by type and
    // stage, and one registry serving both would have to take a null.
    final providers =
        File('lib/src/garden/decor_providers.dart').readAsStringSync();

    expect(providers, contains('decorSpriteRegistryProvider'));
    expect(providers, contains('PlaceholderDecorSpriteRegistry'));
  });
}

/// The files allowed to know what a plant looks like: the registry, the sprites
/// it hands out, and the atlas they are baked into.
///
/// `garden_atlas.dart` earns its place by not weakening the rule. It names no
/// asset: it asks the registry for sprites, has them paint themselves into a
/// texture once, and owns the `drawAtlas` that blits them back out. Ticket 07's
/// painter therefore never touches an image at all, which is why the garden —
/// the screen with two hundred plants on it — is not on this list.
///
/// **`image_sprites.dart` is ticket 23's addition, and it is the one this whole
/// rule was written in anticipation of.** It draws a decoded image because that
/// is what a delivered watercolour *is*; it earns its place on exactly the same
/// terms the atlas does, by being reached through the registry and by naming no
/// asset itself. The paths live in the manifest, and the only code that reads
/// them is `art_bundle.dart`, which hands the decoded images over and never
/// draws one.
///
/// That the list grew by one file for the entire art swap is the measure of
/// whether ticket 04's seam held.
bool _mayNameAnImage(String path) =>
    path.contains('lib/src/garden/plant_sprite.dart') ||
    path.contains('lib/src/garden/placeholder_plant_sprites.dart') ||
    path.contains('lib/src/garden/image_sprites.dart') ||
    path.contains('lib/src/garden/garden_atlas.dart');

/// Every way Flutter offers to get a picture onto the screen.
///
/// Deliberately broad. A false positive here is a one-line change to this list
/// with a reason attached; a false negative is a screen that ticket 23 forgets
/// to update.
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

/// The bundled assets that are not pictures.
///
/// `rootBundle.load` is on the list above because it is a way an image reaches
/// the screen; it is also the only way to read *any* asset, and REQ-031 has five
/// that nobody looks at — the end sounds, which iOS needs copied out of the
/// bundle before a notification can play one. Matched by the sound's own
/// vocabulary rather than by exempting the file, so that file naming a plant
/// image would still be caught — which is why the local at the `load` call
/// site is called `endSoundFile` and not `asset`.
///
/// Named exactly rather than by prefix: `\bendSound` would exempt any line
/// mentioning `endSoundPlayerProvider`, which is most of the feedback layer and
/// none of this rule's business.
final _soundAsset = RegExp(r'\bendSoundFile\b|\bwindChime|\.wav\b');

Iterable<File> _dartFilesUnder(String directory) => Directory(directory)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));
