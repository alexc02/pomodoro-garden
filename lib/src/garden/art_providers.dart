import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'art_bundle.dart';

/// Which asset bundle the art is read from. Overridable so tests don't have
/// to decode the whole art set.
final artAssetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

/// The decoded art, or null if this build ships none (placeholders get used).
///
/// Only a missing manifest counts as "no art". A manifest that's present but
/// broken makes [ArtBundle.load] throw, so a half-built set never ships.
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
