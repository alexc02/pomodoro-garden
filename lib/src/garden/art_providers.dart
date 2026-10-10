import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'art_bundle.dart';

/// Which asset bundle the art is read from.
///
/// A provider so a test can hand over a bundle it built itself rather than
/// decoding seventy-eight files it does not care about. Production reads
/// [rootBundle], which is the app's own.
final artAssetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

/// The decoded art, or null on a device that has none.
///
/// **Null is a real answer and not a failure.** Until PRD §9.1's illustrator
/// delivers, the app runs on ticket 04's placeholder shapes, and it has to go on
/// being able to: an art set that is simply *absent* leaves an app that draws
/// circles, which is what it has drawn all along. What must not be silent is art
/// that is present and *wrong* — a manifest naming a file that is not there, or
/// missing a plant — because that ships a garden with holes in it looking like a
/// style choice. So [ArtBundle.load] throws on a broken set, and this catches
/// only the one case it is entitled to.
///
/// The difference is drawn on whether the manifest exists at all.
final artBundleProvider = FutureProvider<ArtBundle?>((ref) async {
  final bundle = ref.watch(artAssetBundleProvider);

  try {
    await bundle.loadString(ArtBundle.manifestAsset);
  } on Exception {
    // No manifest: this build ships no art, and the placeholders stand.
    return null;
  }

  final art = await ArtBundle.load(bundle);
  ref.onDispose(art.dispose);
  return art;
});
